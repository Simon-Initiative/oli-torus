defmodule Oli.Delivery.Evaluation.Actions.NavigationActionResult do
  @derive Jason.Encoder
  defstruct [:type, :to, :error, :attempt_guid]
end
