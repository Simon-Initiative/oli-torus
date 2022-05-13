defmodule Oli.Delivery.Evaluation.Actions.StateUpdateAction do
  @derive Jason.Encoder
  defstruct [:type, :update, :error, :attempt_guid]
end
