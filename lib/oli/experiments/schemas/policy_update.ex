defmodule Oli.Experiments.Schemas.PolicyUpdate do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Oli.Experiments.Schemas.{Condition, PolicyState, Reward}

  schema "experiment_policy_updates" do
    field :previous_state, :map, default: %{}
    field :next_state, :map, default: %{}
    field :algorithm_version, :string
    field :update_reason, :string

    belongs_to :policy_state, PolicyState
    belongs_to :reward, Reward
    belongs_to :condition, Condition

    timestamps(type: :utc_datetime)
  end

  def changeset(policy_update, attrs \\ %{}) do
    policy_update
    |> cast(attrs, [
      :policy_state_id,
      :reward_id,
      :condition_id,
      :previous_state,
      :next_state,
      :algorithm_version,
      :update_reason
    ])
    |> validate_required([
      :policy_state_id,
      :reward_id,
      :condition_id,
      :previous_state,
      :next_state,
      :algorithm_version
    ])
    |> validate_length(:algorithm_version, min: 1, max: 255)
    |> foreign_key_constraint(:policy_state_id)
    |> foreign_key_constraint(:reward_id)
    |> foreign_key_constraint(:condition_id)
    |> unique_constraint(:reward_id)
  end
end
