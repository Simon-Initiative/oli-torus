defmodule Oli.Delivery.Attempts.Result do

  @enforce_keys [:score, :out_of]
  defstruct [:score, :out_of]

end
