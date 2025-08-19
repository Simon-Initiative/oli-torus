defmodule Oli.Auditing.BrowseOptions do
  @moduledoc """
  Parameters for browsing and filtering audit log events.
  """

  @enforce_keys []
  defstruct [
    :text_search,
    :event_type,
    :actor_type,
    :date_from,
    :date_to,
    :project_id,
    :section_id
  ]

  @type t() :: %__MODULE__{
          text_search: String.t() | nil,
          event_type: atom() | nil,
          actor_type: :user | :author | nil,
          date_from: Date.t() | DateTime.t() | nil,
          date_to: Date.t() | DateTime.t() | nil,
          project_id: integer() | nil,
          section_id: integer() | nil
        }
end
