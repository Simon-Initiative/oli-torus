defmodule Oli.Delivery.Attempts.ManualGrading.BrowseOptions do
  @moduledoc """
  Params for manual graded activity attempt browse queries.
  """

  @enforce_keys [
    :user_id,
    :activity_id,
    :page_id,
    :graded,
    :text_search
  ]

  defstruct [
    :user_id,       # Filter attempts for a specific user id
    :activity_id,   # Filter attempts for a specific activity resource id
    :page_id,       # Filter attempts for a specific page resource id
    :graded,        # Filter attempts for graded, ungraded attempts (nil shows all)
    :text_search    # Text search across user, page, and activity information
  ]

  @type t() :: %__MODULE__{
          user_id: integer(),
          activity_id: integer(),
          page_id: integer(),
          graded: boolean(),
          text_search: String.t()
        }
end
