defmodule Oli.Delivery.Evaluation.Actions.NavigationAction do
  @derive Jason.Encoder
  defstruct [:type, :to, :error, :attempt_guid]
end
