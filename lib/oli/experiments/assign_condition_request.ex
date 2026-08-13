defmodule Oli.Experiments.AssignConditionRequest do
  @moduledoc """
  Delivery request for choosing an experiment condition.
  """

  alias Oli.Experiments.Scope

  defstruct [
    :scope,
    :alternatives_resource_id,
    :alternatives_revision_id,
    :page_resource_id,
    :page_revision_id,
    :content_element_id,
    available_condition_codes: []
  ]

  @type t :: %__MODULE__{
          scope: Scope.t(),
          alternatives_resource_id: integer(),
          alternatives_revision_id: integer(),
          page_resource_id: integer() | nil,
          page_revision_id: integer() | nil,
          content_element_id: String.t() | nil,
          available_condition_codes: [String.t()]
        }
end
