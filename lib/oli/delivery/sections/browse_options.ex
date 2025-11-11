defmodule Oli.Delivery.Sections.BrowseOptions do
  @moduledoc """
  Params for browse sections queries.
  """

  @enforce_keys [
    :institution_id,
    :blueprint_id,
    :project_id,
    :text_search,
    :active_today,
    :filter_status,
    :filter_type
  ]

  defstruct [
    :institution_id,
    :blueprint_id,
    :project_id,
    :text_search,
    :active_today,
    :filter_status,
    :filter_type,
    :filter_requires_payment,
    :filter_tag_ids,
    :filter_date_from,
    :filter_date_to,
    :filter_date_field
  ]

  @type t() :: %__MODULE__{
          institution_id: integer() | nil,
          blueprint_id: integer() | nil,
          project_id: integer() | nil,
          text_search: String.t(),
          active_today: boolean(),
          filter_status: atom() | nil,
          filter_type: atom() | nil,
          filter_requires_payment: boolean() | nil,
          filter_tag_ids: [integer()] | nil,
          filter_date_from: NaiveDateTime.t() | nil,
          filter_date_to: NaiveDateTime.t() | nil,
          filter_date_field: atom() | nil
        }
end
