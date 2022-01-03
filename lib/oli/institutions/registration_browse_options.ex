defmodule Oli.Institutions.RegistrationBrowseOptions do
  @moduledoc """
  Params for browse queries.
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
