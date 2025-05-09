defmodule Oli.Delivery.Evaluation.Standard do
  alias Oli.Delivery.Evaluation.EvaluationContext
  alias Oli.Activities.Model.Part

  def perform(
        attempt_guid,
        %EvaluationContext{} = evaluation_context,
        %Part{} = part,
        scale_factor
      ) do
    case Oli.Delivery.Evaluation.Evaluator.evaluate(part, evaluation_context, scale_factor) do
      {:error, e} ->
        {:error,
         %Oli.Delivery.Evaluation.Actions.FeedbackAction{
           type: "FeedbackAction",
           attempt_guid: attempt_guid,
           feedback: %{},
           score: 0,
           out_of: 0,
           part_id: part.id,
           error: e
         }}

      other ->
        other
    end
  end
end
