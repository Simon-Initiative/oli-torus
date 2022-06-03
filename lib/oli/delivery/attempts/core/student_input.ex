defmodule Oli.Delivery.Attempts.Core.StudentInput do
  @enforce_keys [:input]
  @derive Jason.Encoder
  defstruct [:input, :files]
end
