defmodule Oli.Experiments.Schemas.PolicyState do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Oli.Experiments.Schemas.{DecisionPoint, ExperimentDefinition}

  @algorithms ExperimentDefinition.algorithms()

  schema "experiment_policy_states" do
    field :algorithm, Ecto.Enum, values: @algorithms
    field :algorithm_version, :string
    field :state, :map, default: %{}
    field :prior_config, :map, default: %{}
    field :reward_success_count, :integer, default: 0
    field :reward_failure_count, :integer, default: 0
    field :assignment_count, :integer, default: 0

    belongs_to :experiment, ExperimentDefinition
    belongs_to :decision_point, DecisionPoint

    timestamps(type: :utc_datetime)
  end

  def changeset(policy_state, attrs \\ %{}) do
    policy_state
    |> cast(attrs, [
      :experiment_id,
      :decision_point_id,
      :algorithm,
      :algorithm_version,
      :state,
      :prior_config,
      :reward_success_count,
      :reward_failure_count,
      :assignment_count
    ])
    |> validate_required([
      :experiment_id,
      :decision_point_id,
      :algorithm,
      :algorithm_version,
      :state,
      :prior_config,
      :reward_success_count,
      :reward_failure_count,
      :assignment_count
    ])
    |> validate_length(:algorithm_version, min: 1, max: 255)
    |> validate_number(:reward_success_count, greater_than_or_equal_to: 0)
    |> validate_number(:reward_failure_count, greater_than_or_equal_to: 0)
    |> validate_number(:assignment_count, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:experiment_id)
    |> foreign_key_constraint(:decision_point_id)
    |> unique_constraint([:experiment_id, :decision_point_id, :algorithm],
      name: :experiment_policy_states_unique_idx
    )
  end
end
