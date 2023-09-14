defmodule Oli.Delivery.Sections.BlueprintBrowseOptions do
  @moduledoc """
  Params for browse blueprint sections queries.
  """

  @enforce_keys [
    :project_id,
    :include_archived
  ]

  defstruct [
    :project_id,
    :include_archived
  ]

  @type t() :: %__MODULE__{
          project_id: integer(),
          include_archived: boolean()
        }
end
