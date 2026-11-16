defmodule Oli.Authoring.Audited.Settings do
  @moduledoc false
  # Raw project settings writes, used only by `Oli.Authoring.Audited`, which owns the
  # transaction and records the events.

  import Ecto.Query, only: [from: 2]

  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.{Project, ProjectAttributes}
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing.ChangeTracker
  alias Oli.Repo
  alias Oli.Resources.{ResourceType, ScoringStrategy}

  # Project fields a settings command may write. Status, triggers, the survey link, and the
  # learning model have their own commands; identity and system fields are never written.
  @settings_fields ~w(title description visibility allow_duplication experiments_enabled
    alternatives_enabled allow_ecl_content_type publisher_id allow_transfer_payment_codes
    welcome_title encouraging_subtitle auto_update_sections customizations attributes)a

  # Fields an archive import fills in after the project exists.
  @import_fields ~w(customizations required_survey_resource_id)a

  @doc "Project fields a settings command may write."
  def settings_fields, do: @settings_fields

  @doc "Fields an archive import fills in after creating the project."
  def import_fields, do: @import_fields

  @doc """
  Returns `:ok` when every key of `attrs` names one of `allowed`, or `{:error, :protected}`.
  Keys may be atoms or strings, as forms send them.
  """
  def check_keys(attrs, allowed) do
    allowed = MapSet.new(allowed, &Atom.to_string/1)

    case Enum.all?(Map.keys(attrs), &MapSet.member?(allowed, to_string(&1))) do
      true -> :ok
      false -> {:error, :protected}
    end
  end

  @doc """
  Builds the settings changeset. `attributes` is merged into the persisted embed, so fields a
  caller omits keep their values; every other key goes through `Project.changeset/2`.
  """
  def changeset(%Project{} = project, attrs) do
    {attributes, attrs} = pop_either(attrs, :attributes)
    changeset = Project.changeset(project, attrs)

    case attributes do
      nil ->
        changeset

      attributes ->
        params = merged_attributes(project.attributes, attributes)

        Ecto.Changeset.put_embed(
          changeset,
          :attributes,
          ProjectAttributes.changeset(%ProjectAttributes{}, params)
        )
    end
  end

  # The embeds cannot be cast over their persisted values (the license embed refuses
  # replacement), so the persisted values and the new ones are merged into fresh parameters.
  defp merged_attributes(current, attributes) do
    persisted = embed_params(current)
    attributes = stringify(attributes)

    merged = Map.merge(persisted, Map.delete(attributes, "license"))

    case {Map.get(persisted, "license"), Map.get(attributes, "license")} do
      {nil, nil} ->
        merged

      {license, nil} ->
        Map.put(merged, "license", license)

      {license, changes} ->
        Map.put(merged, "license", Map.merge(license || %{}, stringify(changes)))
    end
  end

  defp embed_params(nil), do: %{}

  defp embed_params(%_{} = embed) do
    embed
    |> Map.from_struct()
    |> Map.new(fn
      {key, %_{} = nested} -> {Atom.to_string(key), embed_params(nested)}
      {key, value} -> {Atom.to_string(key), value}
    end)
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp stringify(map) when is_map(map), do: Map.new(map, fn {k, v} -> {to_string(k), v} end)

  @doc """
  Flattens a project into the fields of the settings policy: attribute and license subfields
  are recorded by name.
  """
  def view(%Project{} = project) do
    attributes = project.attributes || %ProjectAttributes{}
    license = attributes.license

    project
    |> Map.from_struct()
    |> Map.merge(%{
      learning_language: attributes.learning_language,
      calculate_embeddings_on_publish: attributes.calculate_embeddings_on_publish,
      coverage_formative_threshold: attributes.coverage_formative_threshold,
      coverage_summative_threshold: attributes.coverage_summative_threshold,
      license_type: license && license.license_type,
      custom_license_details: license && license.custom_license_details
    })
  end

  @doc """
  Moves the project and its product templates from the legacy learning model to LKT-AOA.
  Returns the updated project and the number of templates, or `:not_upgradable` when the project
  is not an active project on the legacy model. Must run inside a transaction.
  """
  def upgrade_learning_model(%Project{} = project) do
    updates = [
      learning_model_version: :lkt_aoa,
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    ]

    query =
      from(p in Project,
        where: p.id == ^project.id and p.status == :active and p.learning_model_version == :naive,
        select: p
      )

    case Repo.update_all(query, set: updates) do
      {1, [updated]} ->
        {blueprint_count, _} =
          Repo.update_all(
            from(s in Section, where: s.base_project_id == ^project.id and s.type == :blueprint),
            set: updates
          )

        {:ok, {updated, blueprint_count}}

      {0, []} ->
        {:error, :not_upgradable}
    end
  end

  @doc """
  Creates the survey page and links it to the project. Must run inside a transaction.
  """
  def create_survey(%Project{required_survey_resource_id: nil} = project, author_id) do
    with {:ok, %{revision: revision}} <-
           Course.create_and_attach_resource(project, %{
             title: "Course Survey",
             author_id: author_id,
             max_attempts: 1,
             scoring_strategy_id: ScoringStrategy.get_id_by_type("most_recent"),
             resource_type_id: ResourceType.id_for_page(),
             content: %{"version" => "0.1.0", "model" => []}
           }),
         {:ok, project} <- link_survey(project, revision.resource_id),
         {:ok, _} <- ChangeTracker.track_revision(project.slug, revision) do
      {:ok, {project, revision}}
    end
  end

  def create_survey(%Project{}, _author_id), do: {:error, "The project already has a survey"}

  @doc """
  Unlinks the survey page and marks it deleted. Must run inside a transaction.
  """
  def delete_survey(%Project{required_survey_resource_id: nil}),
    do: {:error, "The project doesn't have a survey"}

  def delete_survey(%Project{} = project) do
    revision = Course.get_project_survey(project.id)

    with {:ok, project} <- link_survey(project, nil),
         :ok <- mark_survey_deleted(project, revision) do
      {:ok, project}
    end
  end

  defp mark_survey_deleted(_project, nil), do: :ok

  defp mark_survey_deleted(project, revision) do
    case ChangeTracker.track_revision(project.slug, revision, %{deleted: true}) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp link_survey(project, resource_id) do
    project
    |> Project.changeset(%{required_survey_resource_id: resource_id})
    |> Repo.update()
  end

  defp pop_either(attrs, key) do
    case Map.pop(attrs, key) do
      {nil, attrs} -> Map.pop(attrs, Atom.to_string(key))
      found -> found
    end
  end
end
