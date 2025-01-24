defmodule Oli.Conversation.Triggers  do

  import Ecto.Query
  alias Oli.Repo

  alias Phoenix.PubSub
  alias Oli.Conversation.Trigger

  @trigger_types [
    :visit_page,
    :content_group,
    :content_block,
    :correct_answer,
    :incorrect_answer,
    :hint_request,
    :explanation,
    :targeted_feedback
  ]

  def description(:visit_page, _), do: "Visited the learning page"
  def description(:content_group, id), do: "Clicked a button next to a content group id (id: #{id})"
  def description(:content_block, id), do: "Viewed a content block (id: #{id})"
  def description(:correct_answer, data), do: "Answered correctly question: #{data.question}"
  def description(:incorrect_answer, data), do: "Answered incorrectly question: #{data.question}"
  def description(:hint_request, data), do: "Requested a hint (id: #{data.id}) from question: #{data.question}"
  def description(:explanation, data), do: "Received the explanation (id: #{data.id}) from question: #{data.question}"
  def description(:targeted_feedback, data), do: "Received targeted feedback (id: #{data.id}) from question: #{data.question}"

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

    PubSub.broadcast(
      Oli.PubSub,
      topic,
      {:trigger, trigger}
    )
  end

  def assemble_trigger_prompt(trigger) do

    trigger = augment_data_context(trigger)
    reason = description(trigger.type, trigger.data)

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

      %{type: t} when t in [:visit_page, :content_group, :content_block] -> trigger

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

    case Enum.filter(part.trigger, fn t -> t.type == :hint_request end) do
      [trigger | _other] ->

        trigger = %Trigger{
          type: :hint_request,
          data: %{
            "id" => hint.id,
            "hint" => hint.hint,
            "activity_id" => activity_attempt.resource_id
          },
          resource_id: activity_attempt.resource_id,
          prompt: trigger.prompt
        }

        {section_id, user_id} = get_section_user_ids(activity_attempt)

        invoke(section_id, user_id, trigger)
      _ ->
        :none
    end

  end

  defp get_section_user_ids(activity_attempt) do
    Oli.Delivery.Attempts.Core.ActivityAttempt
    |> join(:left, [a], ra in Oli.Delivery.Attempts.Core.ResourceAttempt, on: ra.id == a.resource_attempt_id)
    |> join(:left, [_, r], ra in Oli.Delivery.Attempts.Core.ResourceAccess, on: ra.id == r.resource_access_id)
    |> where([a, _, _], a.id == ^activity_attempt.id)
    |> select([_, _, ra], {ra.section_id, ra.user_id})
    |> Repo.one()
  end

end
