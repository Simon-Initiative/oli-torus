defmodule Oli.Repo.Paging do
  @moduledoc """
  Params for paging queries.
  """

  @enforce_keys [
    :offset,
    :limit
  ]

  defstruct [
    :offset,
    :limit
  ]

  @type t() :: %__MODULE__{
          offset: integer(),
          limit: integer()
        }
end
