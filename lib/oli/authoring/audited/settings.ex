defmodule Oli.Authoring.Audited.Settings do
  @moduledoc false
  # Project settings commands of `Oli.Authoring.Audited`, which validates their arguments, and
  # the settings writes they run.

  import Ecto.Query, only: [from: 2]
  import Oli.Authoring.Audited.Support, only: [record: 2]

  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias Oli.Auditing.{Changes, Context, LogEvent}
  alias Oli.Auditing.EventCatalog.Fields
  alias Oli.Authoring.Audited.Projects
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

  ## Commands

  def update_project_settings(context, project_id, attrs, allowed) do
    case allowed -- @settings_fields do
      [] -> :ok
      fields -> raise ArgumentError, "not project settings fields: #{inspect(fields)}"
    end

    with :ok <- check_keys(attrs, allowed) do
      change_settings(context, project_id, fn project ->
        project |> changeset(attrs) |> Repo.update()
      end)
    end
  end

  def enable_triggers(context, project_id) do
    change_settings(
      context,
      project_id,
      fn project ->
        project |> Project.changeset(%{allow_triggers: true}) |> Repo.update()
      end,
      event: :activation_settings_changed
    )
  end

  def upgrade_learning_model(context, project_id) do
    change_settings(context, project_id, fn project ->
      with :ok <- project_author(context, project),
           {:ok, {upgraded, blueprint_count}} <- upgrade_model(project) do
        {:ok, upgraded, %{blueprint_count: blueprint_count}}
      end
    end)
  end

  def create_project_survey(%Context{author_id: author_id} = context, project_id) do
    Repo.transaction(fn ->
      with {:ok, before} <- Projects.lock_project(project_id),
           {:ok, {updated, revision}} <- create_survey(before, author_id),
           :ok <- record_settings(context, :project_settings_changed, before, updated, %{}) do
        revision
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def delete_project_survey(context, project_id),
    do: change_settings(context, project_id, &delete_survey/1)

  def complete_import(context, project, attrs) do
    with :ok <- check_keys(attrs, @import_fields),
         :ok <- importing(context, project.id) do
      project |> Project.changeset(attrs) |> Repo.update()
    end
  end

  # The ingest builds one context per import, so its operation ID identifies the import that
  # created the project; an earlier import of the same archive has another operation ID.
  defp importing(%Context{operation_id: operation_id}, project_id) do
    query =
      from(e in LogEvent,
        where:
          e.project_id == ^project_id and e.event_type == :project_imported and
            e.operation_id == ^operation_id
      )

    case Repo.in_transaction?() and Repo.exists?(query) do
      true -> :ok
      false -> {:error, :not_importing}
    end
  end

  # Locks the project, applies `change`, and records the settings that changed. `change` returns
  # `{:ok, project}`, `{:ok, project, details}`, or `{:error, reason}`.
  defp change_settings(context, project_id, change, opts \\ []) do
    event_type = Keyword.get(opts, :event, :project_settings_changed)

    Repo.transaction(fn ->
      with {:ok, before} <- Projects.lock_project(project_id),
           {:ok, updated, details} <- with_details(change.(before)),
           :ok <- record_settings(context, event_type, before, updated, details) do
        updated
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp with_details({:ok, updated}), do: {:ok, updated, %{}}
  defp with_details({:ok, _updated, _details} = result), do: result
  defp with_details({:error, _reason} = error), do: error

  defp record_settings(context, event_type, before, updated, details) do
    {policy, key} =
      case event_type do
        :project_settings_changed -> {Fields.project_settings(), "settings_changed"}
        :activation_settings_changed -> {%{allow_triggers: :value}, "activation_settings_changed"}
      end

    case Changes.diff(view(before), view(updated), policy) do
      changes when map_size(changes) == 0 ->
        :ok

      changes ->
        record(context, %{
          event_type: event_type,
          entity: {:project, updated.id, updated},
          scope: %{project_id: updated.id},
          event_key: "project:#{updated.id}:#{key}",
          changes: changes,
          details: details
        })
    end
  end

  defp project_author(%Context{actor_type: :author, author_id: author_id}, project) do
    case Repo.get(Author, author_id) do
      %Author{} = author ->
        case Accounts.can_access?(author, project) do
          true -> :ok
          false -> {:error, :not_authorized}
        end

      nil ->
        {:error, :not_authorized}
    end
  end

  defp project_author(_context, _project), do: {:error, :not_authorized}

  ## Writes

  @doc "Project fields a settings command may write."
  def settings_fields, do: @settings_fields

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
  def upgrade_model(%Project{} = project) do
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
