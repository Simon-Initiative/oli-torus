defmodule Oli.Delivery.Attempts.Result do

  @enforce_keys [:score, :out_of]
  @derive Jason.Encoder
  defstruct [:score, :out_of]

end
