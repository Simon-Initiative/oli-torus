defmodule Oli.Delivery.Evaluation.Evaluator do
  alias Oli.Delivery.Evaluation.{EvaluationContext}
  alias Oli.Delivery.Evaluation.Actions.{SubmissionActionResult, FeedbackActionResult}
  alias Oli.Activities.Model.{Part, Response}
  alias Oli.Delivery.Evaluation.Rule
  alias Oli.Activities.ParseUtils

  @doc """
  Evaluates a student input for a given activity part.  In a successful
  evaluation, returns the feedback and a scoring result.
  """
  def evaluate(%Part{grading_approach: :manual, id: part_id}, %EvaluationContext{
        part_attempt_guid: attempt_guid
      }) do
    {:ok,
     %SubmissionActionResult{
       type: "SubmissionActionResult",
       attempt_guid: attempt_guid,
       part_id: part_id
     }}
  end

  def evaluate(%Part{} = part, %EvaluationContext{} = context) do
    case Enum.reduce(part.responses, {context, nil, 0, 0}, &consider_response/2) do
      {_, %Response{feedback: feedback, score: score}, _, out_of} ->
        {:ok,
         %FeedbackActionResult{
           type: "FeedbackActionResult",
           score: score,
           out_of: out_of,
           feedback: feedback,
           attempt_guid: context.part_attempt_guid,
           error: nil,
           part_id: part.id
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
         %FeedbackActionResult{
           type: "FeedbackActionResult",
           score: 0,
           out_of: adjusted_out_of,
           feedback: ParseUtils.default_content_item("Incorrect"),
           attempt_guid: context.part_attempt_guid,
           error: nil,
           part_id: part.id
         }}

      _ ->
        {:error, "Error in evaluation"}
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
        {:ok, result} -> result
        {:error, _} -> false
      end

    if matches and (best_score < score or is_nil(best_response)) do
      {context, current, score, out_of}
    else
      {context, best_response, best_score, out_of}
    end
  end
end
