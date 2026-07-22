defmodule Oli.Experiments.Schemas.Outcome do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, ResourceAttempt}
  alias Oli.Experiments.Schemas.Assignment
  alias Oli.Resources.Resource

  schema "experiment_outcomes" do
    field :score, :float
    field :out_of, :float
    field :metadata, :map, default: %{}
    field :observed_at, :utc_datetime
    field :idempotency_key, :string

    belongs_to :assignment, Assignment
    belongs_to :activity_attempt, ActivityAttempt
    belongs_to :resource_attempt, ResourceAttempt
    belongs_to :activity_resource, Resource

    timestamps(type: :utc_datetime)
  end

  def changeset(outcome, attrs \\ %{}) do
    outcome
    |> cast(attrs, [
      :assignment_id,
      :activity_attempt_id,
      :resource_attempt_id,
      :activity_resource_id,
      :score,
      :out_of,
      :metadata,
      :observed_at,
      :idempotency_key
    ])
    |> validate_required([:assignment_id, :metadata, :observed_at, :idempotency_key])
    |> validate_length(:idempotency_key, min: 1, max: 255)
    |> foreign_key_constraint(:assignment_id)
    |> foreign_key_constraint(:activity_attempt_id)
    |> foreign_key_constraint(:resource_attempt_id)
    |> foreign_key_constraint(:activity_resource_id)
    |> unique_constraint(:idempotency_key, name: :experiment_outcomes_idempotency_idx)
  end
end
