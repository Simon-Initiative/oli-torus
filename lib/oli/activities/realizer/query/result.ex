defmodule Oli.Activities.Realizer.Query.Result do
  @moduledoc """
  Encapsulates the results of an activity realizer query.
  """

  @derive Jason.Encoder
  @enforce_keys [:rows, :rowCount, :totalCount]
  defstruct [:rows, :rowCount, :totalCount]
end
