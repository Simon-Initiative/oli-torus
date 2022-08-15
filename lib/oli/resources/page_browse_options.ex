defmodule Oli.Resources.PageBrowseOptions do
  @moduledoc """
  Params for browse all pages queries.
  """

  @enforce_keys [
    :text_search,
    :graded,
    :deleted,
    :basic
  ]

  defstruct [
    :text_search,
    :graded,
    :deleted,
    :basic
  ]

  @type t() :: %__MODULE__{
          text_search: String.t(),
          graded: boolean(),
          deleted: boolean(),
          basic: boolean()
        }
end
