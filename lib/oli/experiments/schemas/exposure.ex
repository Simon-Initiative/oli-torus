defmodule Oli.Experiments.Schemas.Exposure do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Oli.Accounts.User
  alias Oli.Delivery.Sections.{Enrollment, Section}
  alias Oli.Experiments.Schemas.{Assignment, Condition, DecisionPoint, ExperimentDefinition}
  alias Oli.Publishing.Publications.Publication
  alias Oli.Resources.Revision

  schema "experiment_exposures" do
    field :exposed_at, :utc_datetime
    field :idempotency_key, :string

    belongs_to :assignment, Assignment
    belongs_to :experiment, ExperimentDefinition
    belongs_to :decision_point, DecisionPoint
    belongs_to :condition, Condition
    belongs_to :section, Section
    belongs_to :enrollment, Enrollment
    belongs_to :user, User
    belongs_to :publication, Publication
    belongs_to :content_revision, Revision

    timestamps(type: :utc_datetime)
  end

  def changeset(exposure, attrs \\ %{}) do
    exposure
    |> cast(attrs, [
      :assignment_id,
      :experiment_id,
      :decision_point_id,
      :condition_id,
      :section_id,
      :enrollment_id,
      :user_id,
      :publication_id,
      :content_revision_id,
      :exposed_at,
      :idempotency_key
    ])
    |> validate_required([
      :assignment_id,
      :experiment_id,
      :decision_point_id,
      :condition_id,
      :section_id,
      :enrollment_id,
      :user_id,
      :content_revision_id,
      :exposed_at,
      :idempotency_key
    ])
    |> validate_length(:idempotency_key, min: 1, max: 255)
    |> foreign_key_constraint(:assignment_id)
    |> foreign_key_constraint(:experiment_id)
    |> foreign_key_constraint(:decision_point_id)
    |> foreign_key_constraint(:condition_id)
    |> foreign_key_constraint(:section_id)
    |> foreign_key_constraint(:enrollment_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:publication_id)
    |> foreign_key_constraint(:content_revision_id)
    |> unique_constraint(:idempotency_key)
  end
end
