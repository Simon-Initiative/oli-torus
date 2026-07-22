defmodule Oli.Experiments.Schemas.Reward do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Oli.Experiments.Schemas.{
    Assignment,
    Condition,
    DecisionPoint,
    ExperimentDefinition,
    Outcome
  }

  schema "experiment_rewards" do
    field :reward_value, :float
    field :reward_source, :string
    field :processed_at, :utc_datetime
    field :idempotency_key, :string
    field :metadata, :map, default: %{}

    belongs_to :assignment, Assignment
    belongs_to :outcome, Outcome
    belongs_to :experiment, ExperimentDefinition
    belongs_to :decision_point, DecisionPoint
    belongs_to :condition, Condition

    timestamps(type: :utc_datetime)
  end

  def changeset(reward, attrs \\ %{}) do
    reward
    |> cast(attrs, [
      :assignment_id,
      :outcome_id,
      :experiment_id,
      :decision_point_id,
      :condition_id,
      :reward_value,
      :reward_source,
      :processed_at,
      :idempotency_key,
      :metadata
    ])
    |> validate_required([
      :assignment_id,
      :experiment_id,
      :decision_point_id,
      :condition_id,
      :reward_value,
      :reward_source,
      :idempotency_key,
      :metadata
    ])
    |> validate_number(:reward_value, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> validate_length(:reward_source, min: 1, max: 255)
    |> validate_length(:idempotency_key, min: 1, max: 255)
    |> foreign_key_constraint(:assignment_id)
    |> foreign_key_constraint(:outcome_id)
    |> foreign_key_constraint(:experiment_id)
    |> foreign_key_constraint(:decision_point_id)
    |> foreign_key_constraint(:condition_id)
    |> unique_constraint(:idempotency_key, name: :experiment_rewards_idempotency_idx)
  end
end
