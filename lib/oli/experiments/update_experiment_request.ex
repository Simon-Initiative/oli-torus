defmodule Oli.Experiments.UpdateExperimentRequest do
  @moduledoc """
  Request to update mutable fields on a draft experiment definition.
  """

  alias Oli.Experiments.Scope

  defstruct [
    :scope,
    :slug,
    :name,
    :description,
    :algorithm,
    :alternatives_resource_id,
    :prior_alpha,
    :prior_beta,
    :warm_up_assignments,
    :max_condition_share,
    :fixed_control_allocation,
    :imbalance_threshold,
    :reward_source,
    :section_ids,
    :assignment_unit,
    :interventions,
    :conditions
  ]

  @type t :: %__MODULE__{
          scope: Scope.t(),
          slug: String.t() | nil,
          name: String.t() | nil,
          description: String.t() | nil,
          algorithm: :weighted_random | :thompson_sampling | nil,
          section_ids: [integer()] | nil,
          assignment_unit: :enrollment | nil,
          alternatives_resource_id: integer() | nil,
          prior_alpha: number() | nil,
          prior_beta: number() | nil,
          warm_up_assignments: non_neg_integer() | nil,
          max_condition_share: number() | nil,
          fixed_control_allocation: number() | nil,
          imbalance_threshold: number() | nil,
          reward_source: String.t() | nil,
          interventions: [map()] | nil,
          conditions: [map()] | nil
        }
end
