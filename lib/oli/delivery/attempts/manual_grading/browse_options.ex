defmodule Oli.Delivery.Attempts.ManualGrading.BrowseOptions do
  @moduledoc """
  Params for manual graded activity attempt browse queries.
  """

  @enforce_keys [
    :user_id,
    :activity_id,
    :graded,
    :text_search
  ]

  defstruct [
    :user_id,
    :activity_id,
    :graded,
    :text_search
  ]

  @type t() :: %__MODULE__{
          user_id: integer(),
          activity_id: integer(),
          graded: boolean(),
          text_search: String.t()
        }
end
