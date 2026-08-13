defmodule Oli.Experiments.Schemas.Assignment do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Oli.Accounts.User
  alias Oli.Delivery.Sections.{Enrollment, Section}
  alias Oli.Experiments.Schemas.{Condition, ExperimentDefinition, Intervention}

  schema "experiment_assignments" do
    field :assigned_by_policy, :string
    field :policy_version, :string
    field :assignment_key, :string
    field :assigned_at, :utc_datetime
    field :runtime_event_state, :map, default: %{}

    belongs_to :experiment, ExperimentDefinition
    belongs_to :condition, Condition
    belongs_to :intervention, Intervention
    belongs_to :section, Section
    belongs_to :enrollment, Enrollment
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  def changeset(assignment, attrs \\ %{}) do
    assignment
    |> cast(attrs, [
      :experiment_id,
      :condition_id,
      :intervention_id,
      :section_id,
      :enrollment_id,
      :user_id,
      :assigned_by_policy,
      :policy_version,
      :assignment_key,
      :assigned_at,
      :runtime_event_state
    ])
    |> validate_required([
      :experiment_id,
      :condition_id,
      :intervention_id,
      :section_id,
      :enrollment_id,
      :user_id,
      :assigned_by_policy,
      :assignment_key,
      :assigned_at,
      :runtime_event_state
    ])
    |> validate_length(:assigned_by_policy, min: 1, max: 255)
    |> validate_length(:assignment_key, min: 1, max: 255)
    |> foreign_key_constraint(:experiment_id)
    |> foreign_key_constraint(:condition_id)
    |> foreign_key_constraint(:intervention_id)
    |> foreign_key_constraint(:intervention_id,
      name: :experiment_assignments_intervention_experiment_fkey,
      message: "does not belong to the selected experiment"
    )
    |> foreign_key_constraint(:condition_id,
      name: :experiment_assignments_condition_experiment_fkey,
      message: "does not belong to the selected experiment"
    )
    |> foreign_key_constraint(:section_id)
    |> foreign_key_constraint(:enrollment_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:intervention_id, :enrollment_id],
      name: :experiment_assignments_intervention_sticky_idx
    )
    |> unique_constraint(:assignment_key, name: :experiment_assignments_key_idx)
  end
end
