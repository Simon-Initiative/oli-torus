defmodule Oli.Delivery.Attempts.ManualGrading.BrowseOptions do
  @moduledoc """
  Params for manual graded activity attempt browse queries. Each id list filters by any of its
  values; an empty list means no filter.
  """

  @enforce_keys [
    :user_ids,
    :activity_ids,
    :page_ids,
    :graded,
    :text_search
  ]

  defstruct [
    # Filter attempts for these user ids ([] shows all)
    :user_ids,
    # Filter attempts for these activity resource ids ([] shows all)
    :activity_ids,
    # Filter attempts for these page resource ids ([] shows all)
    :page_ids,
    # Filter attempts for graded, ungraded attempts (nil shows all)
    :graded,
    # Text search across user, page, and activity information
    :text_search
  ]

  @type t() :: %__MODULE__{
          user_ids: [pos_integer()],
          activity_ids: [pos_integer()],
          page_ids: [pos_integer()],
          graded: boolean() | nil,
          text_search: String.t() | nil
        }
end
