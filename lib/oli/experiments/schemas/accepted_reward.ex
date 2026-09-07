defmodule Oli.Experiments.Schemas.AcceptedReward do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Delivery.Attempts.Core.ResourceAttempt
  alias Oli.Delivery.Sections.Enrollment
  alias Oli.Experiments.Schemas.{AssessmentBinding, Assignment}

  schema "experiment_accepted_rewards" do
    field :reward, :integer
    field :normalized_score, :decimal
    belongs_to :assessment_binding, AssessmentBinding
    belongs_to :assignment, Assignment
    belongs_to :enrollment, Enrollment
    belongs_to :resource_attempt, ResourceAttempt
    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(reward, attrs \\ %{}) do
    reward
    |> cast(attrs, [
      :assessment_binding_id,
      :assignment_id,
      :enrollment_id,
      :resource_attempt_id,
      :reward,
      :normalized_score
    ])
    |> validate_required([
      :assessment_binding_id,
      :assignment_id,
      :enrollment_id,
      :resource_attempt_id,
      :reward,
      :normalized_score
    ])
    |> validate_inclusion(:reward, [0, 1])
    |> validate_number(:normalized_score,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 1
    )
    |> foreign_key_constraint(:assessment_binding_id)
    |> foreign_key_constraint(:assignment_id)
    |> foreign_key_constraint(:enrollment_id)
    |> foreign_key_constraint(:resource_attempt_id)
    |> unique_constraint([:assessment_binding_id, :enrollment_id],
      name: :experiment_accepted_rewards_enrollment_idx
    )
    |> unique_constraint([:assessment_binding_id, :resource_attempt_id],
      name: :experiment_accepted_rewards_attempt_idx
    )
  end
end
