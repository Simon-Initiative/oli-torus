defmodule Oli.Experiments.Schemas.ExperimentDefinition do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section
  alias Oli.Resources.Resource

  @states [:draft, :active, :paused, :completed, :archived]
  @assignment_units [:enrollment]
  @assignment_scopes [:intervention, :section_enrollment]
  @algorithms [:weighted_random, :thompson_sampling]

  def states, do: @states
  def assignment_units, do: @assignment_units
  def assignment_scopes, do: @assignment_scopes
  def algorithms, do: @algorithms

  schema "experiment_definitions" do
    field :uuid, Ecto.UUID
    field :slug, :string
    field :name, :string
    field :description, :string
    field :state, Ecto.Enum, values: @states, default: :draft
    field :assignment_unit, Ecto.Enum, values: @assignment_units, default: :enrollment
    field :assignment_scope, Ecto.Enum, values: @assignment_scopes, default: :intervention
    field :algorithm, Ecto.Enum, values: @algorithms
    field :prior_alpha, :float, default: 1.0
    field :prior_beta, :float, default: 1.0
    field :warm_up_assignments, :integer, default: 0
    field :max_condition_share, :float, default: 1.0
    field :fixed_control_allocation, :float
    field :imbalance_threshold, :float, default: 1.0
    field :reward_source, :string, default: "assessment_page:normalized_score"
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime

    belongs_to :project, Project
    belongs_to :alternatives_resource, Resource

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
      :assignment_scope,
      :algorithm,
      :alternatives_resource_id,
      :prior_alpha,
      :prior_beta,
      :warm_up_assignments,
      :max_condition_share,
      :fixed_control_allocation,
      :imbalance_threshold,
      :reward_source,
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
      :assignment_scope,
      :algorithm,
      :alternatives_resource_id,
      :prior_alpha,
      :prior_beta,
      :warm_up_assignments,
      :max_condition_share,
      :imbalance_threshold,
      :reward_source
    ])
    |> validate_length(:slug, min: 1, max: 255)
    |> validate_length(:name, min: 1, max: 255)
    |> validate_number(:prior_alpha,
      greater_than_or_equal_to: 0.0001,
      less_than_or_equal_to: 1000
    )
    |> validate_number(:prior_beta, greater_than_or_equal_to: 0.0001, less_than_or_equal_to: 1000)
    |> validate_number(:warm_up_assignments, greater_than_or_equal_to: 0)
    |> validate_number(:max_condition_share, greater_than: 0, less_than_or_equal_to: 1)
    |> validate_number(:fixed_control_allocation,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 1
    )
    |> validate_number(:imbalance_threshold,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 1
    )
    |> validate_inclusion(:reward_source, ["assessment_page:normalized_score"])
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:alternatives_resource_id)
    |> unique_constraint(:uuid, name: :experiment_definitions_uuid_idx)
    |> unique_constraint(:slug, name: :experiment_definitions_project_slug_idx)
    |> unique_constraint(:alternatives_resource_id,
      name: :experiment_definitions_active_alternatives_idx
    )
    |> check_constraint(:assignment_scope,
      name: :experiment_definitions_assignment_scope_check
    )
    |> check_constraint(:assignment_scope,
      name: :experiment_definitions_algorithm_assignment_scope_check,
      message: "section-and-enrollment scope is available only for weighted random experiments"
    )
  end

  defp put_uuid(changeset) do
    case get_field(changeset, :uuid) do
      nil -> put_change(changeset, :uuid, Ecto.UUID.generate())
      _uuid -> changeset
    end
  end
end
