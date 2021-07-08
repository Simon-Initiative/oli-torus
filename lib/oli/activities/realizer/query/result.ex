defmodule Oli.Activities.Realizer.Query.Result do
  @derive Jason.Encoder
  @enforce_keys [:rows, :rowCount, :totalCount]
  defstruct [:rows, :rowCount, :totalCount]
end
