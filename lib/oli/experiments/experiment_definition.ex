defmodule Oli.Experiments.ExperimentDefinition do
  @moduledoc """
  Public experiment definition returned from the experiments context.
  """

  defstruct [
    :id,
    :uuid,
    :project_id,
    :section_ids,
    :slug,
    :name,
    :description,
    :state,
    :assignment_unit,
    :assignment_scope,
    :algorithm,
    :alternatives_resource_id,
    :prior_alpha,
    :prior_beta,
    :warm_up_assignments,
    :max_condition_share,
    :fixed_control_allocation,
    :imbalance_threshold,
    :reward_source,
    :started_at,
    :ended_at
  ]

  @type t :: %__MODULE__{}
end
