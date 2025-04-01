defmodule Oli.Conversation.Triggers do
  require Logger
  import Ecto.Query
  alias Oli.Repo
  alias Oli.Delivery.Attempts.Core.{ResourceAttempt, ResourceAccess}
  alias Phoenix.PubSub
  alias Oli.Conversation.Trigger
  alias Oli.Activities.Model.{Part}

  # The supported trigger type
  @trigger_types [
    :page,
    :content_group,
    :content_block,
    :correct_answer,
    :incorrect_answer,
    :hint,
    :explanation,
    :targeted_feedback
  ]

  def trigger_types(), do: @trigger_types

  def evaluation_triggers(),
    do: [:correct_answer, :incorrect_answer, :explanation, :targeted_feedback]

  # Given a trigger type and trigger type specific data, formulate an agent readable description
  # that we will use in creating the entire prompt.
  def description(:page, _), do: "Visited the learning page"

  def description(:content_group, data),
    do: "Clicked a button next to a content group id (id: #{data["ref_id"]})"

  def description(:content_block, data), do: "Viewed a content block (id: #{data["ref_id"]})"

  def description(:correct_answer, data),
    do:
      "Answered correctly question: #{data["question"]}. The student's response was #{data["response"]}"

  def description(:incorrect_answer, data),
    do:
      "Answered incorrectly question: #{data["question"]}. The student's response was #{data["response"]}"

  def description(:hint, data),
    do: "Requested a hint (id: #{data["ref_id"]}) from question: #{data["question"]}"

  def description(:explanation, data),
    do: "Received the explanation (id: #{data["ref_id"]}) from question: #{data["question"]}"

  def description(:targeted_feedback, data),
    do: "Received targeted feedback (id: #{data["ref_id"]}) from question: #{data["question"]}"

  @doc """
  Verify that the user is enrolled in a section with
  with the AI agent and triggers enabled.
  """
  def verify_access(section_slug, user_id) do
    case Oli.Accounts.User
         |> join(:left, [u], e in Oli.Delivery.Sections.Enrollment, on: u.id == e.user_id)
         |> join(:left, [_, e], s in Oli.Delivery.Sections.Section, on: s.id == e.section_id)
         |> where(
           [_, e, s],
           s.slug == ^section_slug and s.triggers_enabled == true and s.assistant_enabled == true and
             e.user_id == ^user_id
         )
         |> select([_, _, s], s)
         |> limit(1)
         |> Repo.one() do
      nil -> {:error, :no_access}
      section -> {:ok, section}
    end
  end

  @doc """
  Invoke a trigger point for a given section id and user id.  This will broadcast
  the trigger to the PubSub system - which will be picked up by the AI agent window process
  and displayed to the user.
  """
  def invoke(section_id, current_user_id, trigger) do
    topic = "trigger:#{current_user_id}:#{section_id}:#{trigger.resource_id}"

    Logger.info("Invoking trigger for topic: #{topic}")

    PubSub.broadcast(
      Oli.PubSub,
      topic,
      {:trigger, trigger}
    )
  end

  @doc """
  Given a section slug, user id, and trigger data, possibly invoke the trigger
  if the user has access to the section.
  """
  def possibly_invoke_trigger(section_slug, user_id, trigger) do
    case verify_access(section_slug, user_id) do
      {:ok, section} ->
        invoke(section.id, user_id, trigger)

      e ->
        e
    end
  end

  @doc """
  Assemble the full trigger prompt for a given trigger.
  """
  def assemble_trigger_prompt(trigger) do
    trigger = augment_data_context(trigger)
    reason = description(trigger.trigger_type, trigger.data)

    """
    Trigger points are a feature of this platform that allow a course author to instrument
    various points of student interaction in the course to 'trigger' your (the AI agent)
    intervention. This is one such trigger point invocation. The author has configured this trigger
    in response to a student action or event. Do not mention 'trigger points' ever.

    In this trigger point, the student has just #{reason}

    Engage by greeting the student.

    VERY IMPORTANT: The author has also requested the AI agent to
    follow these specific instructions while engaging with the student:

    #{trigger.prompt}
    """
  end

  # Given certain classes of triggers, augment the data context with additional
  # information that will be needed for the AI agent to render the trigger prompt.
  defp augment_data_context(trigger) do
    case trigger do
      # No additional data needed for these trigger types
      %{trigger_type: t} when t in [:page, :content_group, :content_block] ->
        trigger

      # For these trigger types, we need to fetch the question model and encode it
      %{data: %{"activity_attempt_guid" => guid}} ->
        activity_attempt = Oli.Delivery.Attempts.Core.get_activity_attempt_by(attempt_guid: guid)
        model = Oli.Delivery.Attempts.Core.select_model(activity_attempt)

        encoded = Jason.encode!(model)

        data = Map.put(trigger.data, "question", encoded)
        %{trigger | data: data}
    end
  end

  @doc """
  Check for a hint trigger based on the activity attempt, part attempt, model, and hint.

  If a matching trigger is found, return the trigger, otherwise return nil.
  """
  def check_for_hint_trigger(activity_attempt, part_attempt, model, hint, set_resource_id \\ true) do
    part = Enum.filter(model.parts, fn p -> p.id == part_attempt.part_id end) |> hd()

    hint_ordinal =
      case Enum.find_index(part.hints, fn h -> h.id == hint.id end) do
        nil -> 0
        index -> index + 1
      end

    case Enum.filter(part.triggers, fn t ->
           t.trigger_type == :hint and t.ref_id == hint_ordinal
         end) do
      [trigger | _other] ->
        # we have to look up the page id for this activity attempt
        page_id =
          case set_resource_id do
            true ->
              Repo.one(
                from(ra in ResourceAttempt,
                  join: r in ResourceAccess,
                  on: ra.resource_access_id == r.id,
                  where: ra.id == ^activity_attempt.resource_attempt_id,
                  select: r.resource_id
                )
              )

            false ->
              nil
          end

        %Trigger{
          trigger_type: :hint,
          data: %{
            "ref_id" => hint_ordinal,
            "activity_attempt_guid" => activity_attempt.attempt_guid,
            "activity_id" => activity_attempt.resource_id
          },
          resource_id: page_id,
          prompt: trigger.prompt
        }

      _ ->
        nil
    end
  end

  @doc """
  Check for an explanation trigger based on the part, explanation, and explanation context.

  If a matching trigger is found, return the trigger, otherwise return nil.
  """
  def check_for_explanation_trigger(part, explanation, explanation_context) do
    case Enum.filter(part.triggers, fn t -> t.trigger_type == :explanation end) do
      [] ->
        nil

      [trigger | _other] ->
        {:ok, t} = Oli.Activities.Model.Trigger.parse(trigger)
        payload = Trigger.from_activity_model(t)

        data = %{
          "activity_attempt_guid" => explanation_context.activity_attempt.attempt_guid,
          "ref_id" => explanation.id
        }

        %{
          payload
          | section_id: nil,
            user_id: nil,
            resource_id: explanation_context.resource_revision.resource_id,
            data: data
        }
    end
  end

  @doc """
  For a specific evaluation response, check for the presence of a matching evaluation trigger.

  If a matching trigger is found, return the trigger, otherwise return nil.

  Targeted feedback triggers are given priority over correct/incorrect triggers.
  """
  def check_for_response_trigger(relevant_triggers_by_type, response, out_of, context) do
    case find_matching_trigger(relevant_triggers_by_type, response, out_of) do
      nil ->
        nil

      trigger ->
        # Now convert the activity model represenattion of the trigger to the
        # the data transfer object representation of the trigger
        {:ok, t} = Oli.Activities.Model.Trigger.parse(trigger)
        payload = Trigger.from_activity_model(t)

        data = %{
          "activity_attempt_guid" => context.activity_attempt_guid,
          "ref_id" => trigger.ref_id,
          "response" => response
        }

        %{payload | section_id: nil, user_id: nil, resource_id: context.page_id, data: data}
    end
  end

  defp find_matching_trigger(relevant_triggers_by_type, response, out_of) do
    # Does this response match a targeted feedback trigger?
    targeted_feedback_trigger =
      Map.get(relevant_triggers_by_type, :targeted_feedback, [])
      |> Enum.find(fn trigger ->
        trigger.ref_id == response.id
      end)

    correct_trigger = Map.get(relevant_triggers_by_type, :correct_answer, [nil]) |> hd()
    incorrect_trigger = Map.get(relevant_triggers_by_type, :incorrect_answer, [nil]) |> hd()

    is_correct? = response.score == out_of

    # Look first for a targeted feedback trigger matching the response
    if targeted_feedback_trigger != nil do
      targeted_feedback_trigger
    else
      # If no targeted feedback trigger, look for a correct/incorrect triggers
      if is_correct? do
        correct_trigger
      else
        incorrect_trigger
      end
    end
  end

  def relevant_triggers_by_type(%Part{} = part) do
    Enum.filter(part.triggers, fn trigger ->
      trigger.trigger_type in evaluation_triggers()
    end)
    |> Enum.group_by(& &1.trigger_type)
  end
end
