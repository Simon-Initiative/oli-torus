defmodule Oli.Experiments.Schemas.Assignment do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Oli.Accounts.User
  alias Oli.Delivery.Sections.{Enrollment, Section}
  alias Oli.Experiments.Schemas.{Condition, DecisionPoint, ExperimentDefinition}
  alias Oli.Institutions.Institution
  alias Oli.Publishing.Publications.Publication

  schema "experiment_assignments" do
    field :assigned_by_policy, :string
    field :policy_version, :string
    field :assignment_key, :string
    field :assigned_at, :utc_datetime

    belongs_to :experiment, ExperimentDefinition
    belongs_to :decision_point, DecisionPoint
    belongs_to :condition, Condition
    belongs_to :institution, Institution
    belongs_to :section, Section
    belongs_to :enrollment, Enrollment
    belongs_to :user, User
    belongs_to :publication, Publication

    timestamps(type: :utc_datetime)
  end

  def changeset(assignment, attrs \\ %{}) do
    assignment
    |> cast(attrs, [
      :experiment_id,
      :decision_point_id,
      :condition_id,
      :institution_id,
      :section_id,
      :enrollment_id,
      :user_id,
      :publication_id,
      :assigned_by_policy,
      :policy_version,
      :assignment_key,
      :assigned_at
    ])
    |> validate_required([
      :experiment_id,
      :decision_point_id,
      :condition_id,
      :institution_id,
      :section_id,
      :enrollment_id,
      :user_id,
      :assigned_by_policy,
      :assignment_key,
      :assigned_at
    ])
    |> validate_length(:assigned_by_policy, min: 1, max: 255)
    |> validate_length(:assignment_key, min: 1, max: 255)
    |> foreign_key_constraint(:experiment_id)
    |> foreign_key_constraint(:decision_point_id)
    |> foreign_key_constraint(:condition_id)
    |> foreign_key_constraint(:institution_id)
    |> foreign_key_constraint(:section_id)
    |> foreign_key_constraint(:enrollment_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:publication_id)
    |> unique_constraint([:experiment_id, :decision_point_id, :enrollment_id],
      name: :experiment_assignments_sticky_idx
    )
    |> unique_constraint(:assignment_key, name: :experiment_assignments_key_idx)
  end
end
