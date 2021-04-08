defmodule Oli.Delivery.Attempts.StateUpdateActionResult do
  @derive Jason.Encoder
  defstruct [:type, :update, :error, :attempt_guid]
end
