defmodule Oli.Experiments.AssignConditionRequest do
  @moduledoc """
  Delivery request for choosing an experiment condition.
  """

  alias Oli.Experiments.Scope

  defstruct [
    :scope,
    :alternatives_resource_id,
    :alternatives_revision_id,
    :decision_point_key,
    available_condition_codes: []
  ]

  @type t :: %__MODULE__{
          scope: Scope.t(),
          alternatives_resource_id: integer(),
          alternatives_revision_id: integer(),
          decision_point_key: String.t(),
          available_condition_codes: [String.t()]
        }
end
