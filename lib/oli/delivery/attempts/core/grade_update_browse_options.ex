defmodule Oli.Delivery.Attempts.Core.GradeUpdateBrowseOptions do
  @moduledoc """
  Params for browse user queries.
  """

  @enforce_keys [
    :section_id,
    :user_id,
    :text_search
  ]

  defstruct [
    :section_id,
    :user_id,
    :text_search
  ]

  @type t() :: %__MODULE__{
          section_id: integer(),
          user_id: integer(),
          text_search: String.t()
        }
end
