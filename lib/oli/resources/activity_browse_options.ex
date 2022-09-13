defmodule Oli.Resources.ActivityBrowseOptions do
  @moduledoc """
  Params for browse all pages queries.
  """

  @enforce_keys [
    :text_search,
    :activity_type_id,
    :deleted
  ]

  defstruct [
    :text_search,
    :activity_type_id,
    :deleted
  ]

  @type t() :: %__MODULE__{
          text_search: String.t(),
          deleted: boolean(),
          activity_type_id: integer()
        }
end
