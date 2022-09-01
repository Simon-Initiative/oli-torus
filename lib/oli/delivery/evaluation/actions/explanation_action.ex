defmodule Oli.Delivery.Evaluation.Actions.ExplanationAction do
  @derive Jason.Encoder
  defstruct [:type, :attempt_guid, :explanation, :strategy, :part_id]
end
