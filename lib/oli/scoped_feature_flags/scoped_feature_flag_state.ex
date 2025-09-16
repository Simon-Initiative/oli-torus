defmodule Oli.ScopedFeatureFlags.ScopedFeatureFlagState do
  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section

  schema "scoped_feature_flag_states" do
    field(:feature_name, :string)

    belongs_to(:project, Project)
    belongs_to(:section, Section)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(scoped_feature_flag_state, attrs \\ %{}) do
    scoped_feature_flag_state
    |> cast(attrs, [:feature_name])
    |> validate_required([:feature_name])
    |> validate_length(:feature_name, min: 1, max: 255)
    |> validate_mutual_exclusion()
    |> validate_at_least_one_resource()
    |> unique_constraint([:feature_name, :project_id])
    |> unique_constraint([:feature_name, :section_id])
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:section_id)
  end

  @doc false
  def changeset_with_project(scoped_feature_flag_state, attrs, project_id) do
    scoped_feature_flag_state
    |> cast(attrs, [:feature_name])
    |> validate_required([:feature_name])
    |> validate_length(:feature_name, min: 1, max: 255)
    |> put_change(:project_id, project_id)
    |> validate_mutual_exclusion()
    |> validate_at_least_one_resource()
    |> unique_constraint([:feature_name, :project_id])
    |> unique_constraint([:feature_name, :section_id])
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:section_id)
  end

  @doc false
  def changeset_with_section(scoped_feature_flag_state, attrs, section_id) do
    scoped_feature_flag_state
    |> cast(attrs, [:feature_name])
    |> validate_required([:feature_name])
    |> validate_length(:feature_name, min: 1, max: 255)
    |> put_change(:section_id, section_id)
    |> validate_mutual_exclusion()
    |> validate_at_least_one_resource()
    |> unique_constraint([:feature_name, :project_id])
    |> unique_constraint([:feature_name, :section_id])
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:section_id)
  end

  defp validate_mutual_exclusion(changeset) do
    project_id = get_field(changeset, :project_id)
    section_id = get_field(changeset, :section_id)

    cond do
      project_id && section_id ->
        add_error(changeset, :base, "Cannot specify both project_id and section_id")

      true ->
        changeset
    end
  end

  defp validate_at_least_one_resource(changeset) do
    project_id = get_field(changeset, :project_id)
    section_id = get_field(changeset, :section_id)

    cond do
      is_nil(project_id) && is_nil(section_id) ->
        add_error(changeset, :base, "Must specify either project_id or section_id")

      true ->
        changeset
    end
  end
end
