defmodule Oli.Delivery.Attempts.StudentInput do
  @enforce_keys [:input]
  @derive Jason.Encoder
  defstruct [:input]
end
