defmodule Oli.Delivery.Attempts.Core.ClientEvaluation do
  @enforce_keys [:input, :score, :out_of, :feedback]
  @derive Jason.Encoder
  defstruct [:input, :score, :out_of, :feedback]
end
