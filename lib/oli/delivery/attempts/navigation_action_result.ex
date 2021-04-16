defmodule Oli.Delivery.Attempts.NavigationActionResult do
  @derive Jason.Encoder
  defstruct [:type, :to, :error, :attempt_guid]
end
