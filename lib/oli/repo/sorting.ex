defmodule Oli.Repo.Sorting do
  @moduledoc """
  Params for sorting queries.
  """

  @enforce_keys [
    :field,
    :direction
  ]

  defstruct [
    :field,
    :direction
  ]

  @type t() :: %__MODULE__{
          field: any(),
          direction: :asc | :desc
        }
end
