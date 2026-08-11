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

    field :policy_config, :map, default: %{}

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
      :policy_config
    ])
    |> validate_required([
      :experiment_id,
      :alternatives_resource_id,
      :decision_point_key,
      :position,
      :algorithm,
      :policy_config
    ])
    |> validate_length(:decision_point_key, min: 1, max: 255)
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:experiment_id)
    |> foreign_key_constraint(:alternatives_resource_id)
    |> unique_constraint([:experiment_id, :decision_point_key],
      name: :experiment_decision_points_key_idx
    )
  end
end
