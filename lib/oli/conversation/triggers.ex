defmodule Oli.Conversation.Triggers  do

  import Ecto.Query
  alias Oli.Repo

  alias Phoenix.PubSub
  alias Oli.Conversation.Trigger

  alias Oli.Delivery.Evaluation.{EvaluationContext}
  alias Oli.Activities.Model.{Part, Response}

  @trigger_types [
    :page,
    :content_group,
    :content_block,
    :correct_answer,
    :incorrect_answer,
    :hint_request,
    :explanation,
    :targeted_feedback
  ]

  def evaluation_triggers(), do: [:correct_answer, :incorrect_answer, :explanation, :targeted_feedback]

  def description(:page, _), do: "Visited the learning page"
  def description(:content_group, data), do: "Clicked a button next to a content group id (id: #{data["ref_id"]})"
  def description(:content_block, data), do: "Viewed a content block (id: #{data["ref_id"]})"
  def description(:correct_answer, data), do: "Answered correctly question: #{data["question"]}"
  def description(:incorrect_answer, data), do: "Answered incorrectly question: #{data["question"]}"
  def description(:hint_request, data), do: "Requested a hint (id: #{data["ref_id"]}) from question: #{data["question"]}"
  def description(:explanation, data), do: "Received the explanation (id: #{data["ref_id"]}) from question: #{data["question"]}"
  def description(:targeted_feedback, data), do: "Received targeted feedback (id: #{data["ref_id"]}) from question: #{data["question"]}"

  @doc """
  Verify that the user is enrolled in a section with
  with the AI agent enabled.
  """
  def verify_access(section_slug, user_id) do

   case Oli.Accounts.User
      |> join(:left, [u], e in Oli.Delivery.Sections.Enrollment, on: u.id == e.user_id)
      |> join(:left, [_, e], s in Oli.Delivery.Sections.Section, on: s.id == e.section_id)
      |> where([_, e, s], s.slug == ^section_slug and s.assistant_enabled == true and e.user_id == ^user_id)
      |> select([_, _, s], s)
      |> limit(1)
      |> Repo.one() do

      nil -> {:error, :no_access}

      section -> {:ok, section}

    end

  end

  def invoke(section_id, current_user_id, trigger) do

    topic = "trigger:#{current_user_id}:#{section_id}:#{trigger.resource_id}"

    IO.inspect("broadcasting to #{topic}")

    PubSub.broadcast(
      Oli.PubSub,
      topic,
      {:trigger, trigger}
    )
  end

  def possibly_invoke_trigger(section_slug, user_id, trigger) do
    case verify_access(section_slug, user_id) do
      {:ok, section} ->
        invoke(section.id, user_id, trigger)
      e ->
        e
    end
  end

  def assemble_trigger_prompt(trigger) do

    trigger = augment_data_context(trigger)
    reason = description(trigger.trigger_type, trigger.data)

    prompt = """
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

  defp augment_data_context(trigger) do

    trigger = case trigger do

      %{trigger_type: t} when t in [:page, :content_group, :content_block] -> trigger

      %{data: %{"activity_attempt_guid" => guid}} ->

        activity_attempt = Oli.Delivery.Attempts.Core.get_activity_attempt_by(attempt_guid: guid)
        model = Oli.Delivery.Attempts.Core.select_model(activity_attempt)

        encoded = Jason.encode!(model)

        data = Map.put(trigger.data, "question", encoded)
        %{trigger | data: data}
    end

  end

  def check_for_hint_trigger(activity_attempt, part_attempt, model, hint) do
    part = Enum.filter(model.parts, fn p -> p.id == part_attempt.part_id end) |> hd()

    case Enum.filter(part.trigger, fn t -> t.trigger_type == :hint_request end) do
      [trigger | _other] ->

        %Trigger{
          trigger_type: :hint_request,
          data: %{
            "ref_id" => hint.id,
            "hint" => hint.hint,
            "activity_id" => activity_attempt.resource_id
          },
          resource_id: activity_attempt.resource_id,
          prompt: trigger.prompt
        }

      _ ->
        nil
    end

  end

  def check_for_explanation_trigger(part, explanation, explanation_context) do

    case Enum.filter(part.triggers, fn t -> t.trigger_type == :explanation end) do
      [] -> nil
      [trigger | _other] ->

        {:ok, t} = Oli.Activities.Model.Trigger.parse(trigger)
        payload = Trigger.from_activity_model(t)

        data = %{
          "activity_attempt_guid" => explanation_context.activity_attempt.attempt_guid,
          "ref_id" => explanation.id,
        }

        %{ payload | section_id: nil, user_id: nil, resource_id: explanation_context.resource_revision.resource_id, data: data }

    end
  end

  def check_for_response_trigger(relevant_triggers_by_type, response, out_of, context) do

    case find_matching_trigger(relevant_triggers_by_type, response, out_of) do
      nil -> nil

      trigger ->
        # Now convert the activity model represenattion of the trigger to the
        # the data transfer object representation of the trigger
        {:ok, t} = Oli.Activities.Model.Trigger.parse(trigger)
        payload = Trigger.from_activity_model(t)

        data = %{
          "activity_attempt_guid" => context.activity_attempt_guid,
          "ref_id" => trigger.ref_id,
        }

        %{ payload | section_id: nil, user_id: nil, resource_id: context.page_id, data: data }
    end

  end

  defp find_matching_trigger(relevant_triggers_by_type, response, out_of) do
    # Does this response match a targeted feedback trigger?
    targeted_feedback_trigger = Map.get(relevant_triggers_by_type, :targeted_feedback, [])
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
    |> Enum.group_by(&(&1.trigger_type))
  end

end
