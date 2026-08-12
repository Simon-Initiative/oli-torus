defmodule Oli.Experiments.Schemas.ExperimentDefinition do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section

  @states [:draft, :active, :paused, :completed, :archived]
  @assignment_units [:enrollment]
  @algorithms [:weighted_random, :thompson_sampling]

  def states, do: @states
  def assignment_units, do: @assignment_units
  def algorithms, do: @algorithms

  schema "experiment_definitions" do
    field :uuid, Ecto.UUID
    field :slug, :string
    field :name, :string
    field :description, :string
    field :state, Ecto.Enum, values: @states, default: :draft
    field :assignment_unit, Ecto.Enum, values: @assignment_units, default: :enrollment
    field :algorithm, Ecto.Enum, values: @algorithms
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime

    belongs_to :project, Project

    many_to_many :sections, Section,
      join_through: "experiment_sections",
      join_keys: [experiment_id: :id, section_id: :id]

    timestamps(type: :utc_datetime)
  end

  def changeset(definition, attrs \\ %{}) do
    definition
    |> cast(attrs, [
      :uuid,
      :project_id,
      :slug,
      :name,
      :description,
      :state,
      :assignment_unit,
      :algorithm,
      :started_at,
      :ended_at
    ])
    |> put_uuid()
    |> validate_required([
      :uuid,
      :project_id,
      :slug,
      :name,
      :state,
      :assignment_unit,
      :algorithm
    ])
    |> validate_length(:slug, min: 1, max: 255)
    |> validate_length(:name, min: 1, max: 255)
    |> foreign_key_constraint(:project_id)
    |> unique_constraint(:uuid, name: :experiment_definitions_uuid_idx)
    |> unique_constraint(:slug, name: :experiment_definitions_project_slug_idx)
  end

  defp put_uuid(changeset) do
    case get_field(changeset, :uuid) do
      nil -> put_change(changeset, :uuid, Ecto.UUID.generate())
      _uuid -> changeset
    end
  end
end
