defmodule Oli.Delivery.Attempts.ClientEvaluation do

  @enforce_keys [:score, :out_of, :feedback]
  @derive Jason.Encoder
  defstruct [:score, :out_of, :feedback]

end
