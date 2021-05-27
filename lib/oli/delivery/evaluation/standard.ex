defmodule Oli.Delivery.Evaluation.Standard do
  alias Oli.Delivery.Evaluation.EvaluationContext
  alias Oli.Activities.Model.Part
  alias Oli.Delivery.Evaluation.Result

  def perform(
        attempt_guid,
        %EvaluationContext{} = evaluation_context,
        %Part{} = part
      ) do
    case Oli.Delivery.Evaluation.Evaluator.evaluate(part, evaluation_context) do
      {:ok, {feedback, %Result{score: score, out_of: out_of}}} ->
        {:ok,
         %Oli.Delivery.Evaluation.Actions.FeedbackActionResult{
           type: "FeedbackActionResult",
           attempt_guid: attempt_guid,
           feedback: feedback,
           score: score,
           out_of: out_of
         }}

      {:error, e} ->
        {:error,
         %Oli.Delivery.Evaluation.Actions.FeedbackActionResult{
           type: "FeedbackActionResult",
           attempt_guid: attempt_guid,
           feedback: %{},
           score: 0,
           out_of: 0,
           error: e
         }}
    end
  end
end
