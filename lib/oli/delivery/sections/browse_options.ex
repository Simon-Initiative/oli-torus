defmodule Oli.Delivery.Sections.BrowseOptions do
  @moduledoc """
  Params for browse sections queries.
  """

  @enforce_keys [
    :show_deleted,
    :institution_id,
    :blueprint_id,
    :active_only,
    :text_search
  ]

  defstruct [
    :show_deleted,
    :institution_id,
    :blueprint_id,
    :active_only,
    :text_search
  ]

  @type t() :: %__MODULE__{
          show_deleted: boolean(),
          institution_id: integer(),
          blueprint_id: integer(),
          active_only: boolean(),
          text_search: String.t()
        }
end
