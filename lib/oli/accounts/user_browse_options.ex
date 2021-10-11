defmodule Oli.Accounts.UserBrowseOptions do
  @moduledoc """
  Params for browse user queries.
  """

  @enforce_keys [
    :include_guests,
    :text_search
  ]

  defstruct [
    :include_guests,
    :text_search
  ]

  @type t() :: %__MODULE__{
          include_guests: boolean(),
          text_search: String.t()
        }
end
