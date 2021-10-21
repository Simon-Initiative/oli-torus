defmodule Oli.Accounts.AuthorBrowseOptions do
  @moduledoc """
  Params for browse user queries.
  """

  @enforce_keys [
    :text_search
  ]

  defstruct [
    :text_search
  ]

  @type t() :: %__MODULE__{
          text_search: String.t()
        }
end
