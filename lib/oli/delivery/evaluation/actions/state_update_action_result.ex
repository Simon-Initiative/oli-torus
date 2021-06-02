defmodule Oli.Delivery.Evaluation.Actions.StateUpdateActionResult do
  @derive Jason.Encoder
  defstruct [:type, :update, :error, :attempt_guid]
end
