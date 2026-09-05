defmodule Oli.Experiments.CreateExperimentRequest do
  @moduledoc """
  Request to create a native experiment definition.
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
    interventions: [],
    conditions: [],
    assignment_unit: :enrollment,
    assignment_scope: nil
  ]

  @type t :: %__MODULE__{
          scope: Scope.t(),
          slug: String.t(),
          name: String.t(),
          description: String.t() | nil,
          algorithm: :weighted_random | :thompson_sampling,
          section_ids: [integer()] | nil,
          alternatives_resource_id: integer(),
          prior_alpha: number() | nil,
          prior_beta: number() | nil,
          warm_up_assignments: non_neg_integer() | nil,
          max_condition_share: number() | nil,
          fixed_control_allocation: number() | nil,
          imbalance_threshold: number() | nil,
          reward_source: String.t() | nil,
          interventions: [map()],
          conditions: [map()],
          assignment_unit: :enrollment,
          assignment_scope: :intervention | :section_enrollment | nil
        }
end
