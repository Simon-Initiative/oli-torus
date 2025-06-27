defmodule Oli.Delivery.Attempts.Core.ClientEvaluation do
  @enforce_keys [:score, :out_of]
  @derive Jason.Encoder
  defstruct [:input, :score, :out_of, :feedback, :timestamp]
end
