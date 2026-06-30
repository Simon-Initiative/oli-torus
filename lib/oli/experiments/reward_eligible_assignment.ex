defmodule Oli.Experiments.RewardEligibleAssignment do
  @moduledoc """
  Public delivery-facing receipt for experiment assignments eligible for reward handoff.
  """

  defstruct [
    :assignment_id,
    :experiment_id,
    :decision_point_id,
    :condition_id,
    :condition_code,
    :alternatives_resource_id,
    :alternatives_revision_id
  ]

  @type t :: %__MODULE__{
          assignment_id: integer(),
          experiment_id: integer(),
          decision_point_id: integer(),
          condition_id: integer(),
          condition_code: String.t(),
          alternatives_resource_id: integer(),
          alternatives_revision_id: integer()
        }
end
