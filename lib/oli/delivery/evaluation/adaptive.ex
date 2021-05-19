defmodule Oli.Delivery.Evaluation.Adaptive do
  alias Oli.Delivery.Evaluation.EvaluationContext
  alias Oli.Activities.Model.Part
  alias Oli.Delivery.Evaluation.Result

  def perform(
        attempt_guid,
        %EvaluationContext{} = _,
        %Part{} = _
      ) do
    {:ok,
     %Oli.Delivery.Evaluation.Actions.StateUpdateActionResult{
       type: "StateUpdateActionResult",
       attempt_guid: attempt_guid,
       update: %{}
     }}
  end
end
