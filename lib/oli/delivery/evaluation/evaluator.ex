defmodule Oli.Delivery.Evaluation.Evaluator do
  alias Oli.Delivery.Evaluation.{EvaluationContext}
  alias Oli.Delivery.Evaluation.Actions.{SubmissionAction, FeedbackAction}
  alias Oli.Activities.Model.{Part, Response}
  alias Oli.Delivery.Evaluation.Rule
  alias Oli.Activities.Model.Feedback

  @doc """
  Evaluates a student input for a given activity part.  In a successful
  evaluation, returns the feedback and a scoring result.
  """
  def evaluate(%Part{grading_approach: :manual, id: part_id}, %EvaluationContext{
        part_attempt_guid: attempt_guid
      }) do
    {:ok,
     %SubmissionAction{
       type: "SubmissionAction",
       attempt_guid: attempt_guid,
       part_id: part_id
     }}
  end

  def evaluate(%Part{} = part, %EvaluationContext{} = context) do

    relevant_triggers_by_type = Enum.filter(part.triggers, fn trigger ->
      trigger.type in Oli.Conversation.Triggers.evaluation_triggers()
    end)
    |> Enum.group_by(&(&1.type))

    case Enum.reduce(part.responses, {context, nil, 0, 0}, &consider_response/2) do
      {_, %Response{feedback: feedback, score: score, show_page: show_page} = response _, out_of} ->
        {:ok,
         %FeedbackAction{
           type: "FeedbackAction",
           score: score,
           out_of: out_of,
           feedback: feedback,
           attempt_guid: context.part_attempt_guid,
           error: nil,
           show_page: show_page,
           part_id: part.id,
           trigger: arm_trigger(relevant_triggers_by_type, response, out_of)
         }}

      # No matching response found - mark incorrect
      {_, nil, _, out_of} ->
        # this guarantees that all activities, even unanswered client-side
        # evaluated ones, that have no matching responses get 0 out of
        # a non-zero maximum value
        adjusted_out_of =
          if out_of == 0 do
            1
          else
            out_of
          end

        {:ok,
         %FeedbackAction{
           type: "FeedbackAction",
           score: 0,
           out_of: adjusted_out_of,
           feedback: Feedback.from_text("Incorrect"),
           attempt_guid: context.part_attempt_guid,
           error: nil,
           show_page: nil,
           part_id: part.id
         }}

      _ ->
        {:error, "Error in evaluation"}
    end
  end

  defp arm_trigger(relevant_triggers_by_type, response, out_of) do

    case find_matching_trigger(relevant_triggers_by_type, response, out_of) do
      nil -> nil
      trigger -> Oli.Conversation.Trigger.parse(trigger, nil, nil)
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

    case {targeted_feedback_trigger, correct_trigger, incorrect_trigger, is_correct?} do
      {trigger, _, _, _} -> trigger
      {_, trigger, _, true} -> trigger
      {_, _, trigger, false} -> trigger
      _ -> nil
    end
  end

  # Consider one response
  defp consider_response(
         %Response{score: score, rule: rule} = current,
         {context, best_response, best_score, out_of}
       ) do
    # Track the highest point value out of all responses
    out_of =
      case score > out_of do
        true -> score
        false -> out_of
      end

    matches =
      case Rule.parse_and_evaluate(rule, context) do
        {:ok, result} ->
          result

        {:error, _er} ->
          false
      end

    if matches and (best_score < score or is_nil(best_response)) do
      {context, current, score, out_of}
    else
      {context, best_response, best_score, out_of}
    end
  end
end
