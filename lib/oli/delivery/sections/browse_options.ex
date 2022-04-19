defmodule Oli.Delivery.Sections.BrowseOptions do
  @moduledoc """
  Params for browse sections queries.
  """

  @enforce_keys [
    :institution_id,
    :blueprint_id,
    :text_search,
    :active_date,
    :filter_status,
    :filter_type
  ]

  defstruct [
    :institution_id,
    :blueprint_id,
    :text_search,
    :active_date,
    :filter_status,
    :filter_type
  ]

  @type t() :: %__MODULE__{
          institution_id: integer(),
          blueprint_id: integer(),
          text_search: String.t(),
          active_date: boolean(),
          filter_status: atom(),
          filter_type: atom()
        }
end
