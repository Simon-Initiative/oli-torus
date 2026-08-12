defmodule Oli.Experiments.Schemas.DecisionPoint do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Oli.Experiments.Schemas.{DecisionPointCondition, ExperimentDefinition, Intervention}
  alias Oli.Resources.Resource

  schema "experiment_decision_points" do
    field :decision_point_key, :string
    field :title, :string
    field :position, :integer, default: 0

    field :algorithm, Ecto.Enum,
      values: ExperimentDefinition.algorithms(),
      default: :weighted_random

    field :prior_alpha, :float, default: 1.0
    field :prior_beta, :float, default: 1.0
    field :warm_up_assignments, :integer, default: 0
    field :max_condition_share, :float, default: 1.0
    field :fixed_control_allocation, :float
    field :imbalance_threshold, :float, default: 1.0
    field :reward_source, :string, default: "assessment_page:normalized_score"

    belongs_to :experiment, ExperimentDefinition
    belongs_to :alternatives_resource, Resource
    has_many :condition_mappings, DecisionPointCondition
    has_many :interventions, Intervention

    timestamps(type: :utc_datetime)
  end

  def changeset(decision_point, attrs \\ %{}) do
    decision_point
    |> cast(attrs, [
      :experiment_id,
      :alternatives_resource_id,
      :decision_point_key,
      :title,
      :position,
      :algorithm,
      :prior_alpha,
      :prior_beta,
      :warm_up_assignments,
      :max_condition_share,
      :fixed_control_allocation,
      :imbalance_threshold,
      :reward_source
    ])
    |> validate_required([
      :experiment_id,
      :alternatives_resource_id,
      :decision_point_key,
      :position,
      :algorithm,
      :prior_alpha,
      :prior_beta,
      :warm_up_assignments,
      :max_condition_share,
      :imbalance_threshold,
      :reward_source
    ])
    |> validate_length(:decision_point_key, min: 1, max: 255)
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> validate_number(:prior_alpha,
      greater_than_or_equal_to: 0.0001,
      less_than_or_equal_to: 1000
    )
    |> validate_number(:prior_beta, greater_than_or_equal_to: 0.0001, less_than_or_equal_to: 1000)
    |> validate_number(:warm_up_assignments, greater_than_or_equal_to: 0)
    |> validate_number(:max_condition_share, greater_than: 0, less_than_or_equal_to: 1)
    |> validate_number(:fixed_control_allocation,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 1
    )
    |> validate_number(:imbalance_threshold,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 1
    )
    |> validate_inclusion(:reward_source, ["assessment_page:normalized_score"])
    |> foreign_key_constraint(:experiment_id)
    |> foreign_key_constraint(:alternatives_resource_id)
    |> unique_constraint([:experiment_id, :decision_point_key],
      name: :experiment_decision_points_key_idx
    )
  end
end
