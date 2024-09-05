defmodule Oli.Analytics.Summary.BrowseInsightsOptions do
  @moduledoc """
  Params for browse insights queries.
  """

  @enforce_keys [
    :project_id,
    :section_ids,
    :resource_type_id
  ]

  defstruct [
    :project_id,
    :section_ids,
    :resource_type_id
  ]

  @type t() :: %__MODULE__{
    project_id: integer(),
    section_ids: list(),
    resource_type_id: integer()
  }
end
