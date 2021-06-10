defmodule Oli.Delivery.Evaluation.AdaptiveResult do
  @derive Jason.Encoder
  defstruct [:type, :params, :error, :attempt_guid]
end
