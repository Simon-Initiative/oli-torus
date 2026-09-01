defmodule Oli.Delivery.Sections.SectionResourceMigration do
  @moduledoc """
  Owns deterministic, versioned upgrades of SectionResource projection data.

  First depot access locks and rechecks the Section row, applies every missing
  ordered step, and advances the marker in the same transaction. Failed work is
  therefore retryable and can never make a partial projection appear current.
  """

  alias Oli.Repo
  import Ecto.Query
  alias Oli.Delivery.DepotCoordinator
  alias Oli.Delivery.Sections.RelatedActivitiesProjection
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Delivery.Sections.SectionsProjectsPublications
  alias Oli.Publishing.Publications.Publication
  alias Oli.Publishing.PublishedResource
  alias Oli.Resources.Revision
  alias Oli.Authoring.Course.Project

  @current_version 1
  @migration_steps [1]

  @doc "Returns the complete SectionResource projection version required by this release."
  def current_version, do: @current_version

  @doc """
  Upgrades a legacy Section immediately before its depot table is loaded.

  The row lock serializes concurrent first access. The version is re-read under
  that lock because the value observed before waiting may already be stale.
  """
  @spec ensure_current(integer()) ::
          {:ok, :current | :migrated} | {:error, term()}
  def ensure_current(section_id) do
    Repo.transaction(fn ->
      from(section in Section,
        where: section.id == ^section_id,
        lock: "FOR UPDATE"
      )
      |> Repo.one()
      |> case do
        nil -> Repo.rollback({:section_not_found, section_id})
        section -> migrate_from_version(section)
      end
    end)
    |> case do
      {:ok, result} -> result
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Projects current related activities during ordinary Section lifecycle work.

  Database state and the marker commit together. Outside an enclosing lifecycle
  transaction, updated depot entries are published only after that commit. Inside
  one, callers already clear the depot after their outer transaction succeeds.
  """
  @spec project_current(Section.t()) :: {:ok, Section.t()} | {:error, term()}
  def project_current(%Section{} = section) do
    already_in_transaction? = Repo.in_transaction?()

    Repo.transaction(fn ->
      # Lifecycle creation paths intentionally insert lightweight placeholders.
      # Bring every pinned field current before declaring their projection ready.
      with {:ok, _count} <- migrate(section.id),
           {:ok, _entries} <- projection_module().persist(section, return_entries: false),
           {1, _} <- set_version(section.id, @current_version) do
        %{section | section_resource_migration_version: @current_version}
      else
        {:error, reason} -> Repo.rollback(reason)
        unexpected -> Repo.rollback({:version_update_failed, unexpected})
      end
    end)
    |> case do
      {:ok, updated_section} ->
        case already_in_transaction? do
          true -> {:ok, updated_section}
          false -> clear_projection_depot(updated_section)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp migrate_from_version(%Section{section_resource_migration_version: version})
       when version == @current_version,
       do: {:ok, :current}

  defp migrate_from_version(%Section{section_resource_migration_version: version})
       when version > @current_version,
       do: Repo.rollback({:unsupported_future_version, version})

  defp migrate_from_version(%Section{section_resource_migration_version: version} = section) do
    @migration_steps
    |> Enum.filter(&(&1 > version))
    |> Enum.reduce_while({:ok, section}, fn target_version, {:ok, section} ->
      case apply_step(section, target_version) do
        {:ok, section} -> {:cont, {:ok, section}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, _section} -> {:ok, :migrated}
      {:error, reason} -> Repo.rollback(reason)
    end
  end

  # Each target version gets an explicit clause so future releases append
  # deterministic steps instead of silently folding all old versions together.
  defp apply_step(%Section{} = section, 1) do
    with {:ok, _count} <- migrate(section.id),
         {:ok, _entries} <- projection_module().persist(section, return_entries: false),
         {1, _} <- set_version(section.id, 1) do
      {:ok, %{section | section_resource_migration_version: 1}}
    else
      {:error, reason} -> {:error, reason}
      unexpected -> {:error, {:migration_step_failed, unexpected}}
    end
  end

  defp set_version(section_id, version) do
    Repo.update_all(
      from(section in Section, where: section.id == ^section_id),
      set: [section_resource_migration_version: version, updated_at: DateTime.utc_now()]
    )
  end

  defp clear_projection_depot(section) do
    case DepotCoordinator.clear_synchronously(SectionResourceDepot.depot_desc(), section.id) do
      result when result in [:ok, true, nil] ->
        {:ok, section}

      {:error, reason} ->
        {:error, {:depot_clear_failed, reason}}
    end
  end

  defp projection_module do
    Application.get_env(
      :oli,
      :related_activities_projection,
      RelatedActivitiesProjection
    )
  end

  @doc """
  Returns true if at least one SectionResource record requires migration, false otherwise.
  The check is done on the graded field, since that is one of the fields that get migrated from the pinned revision.
  """
  def requires_migration?(section_id) do
    query =
      from sr in SectionResource,
        where: sr.section_id == ^section_id and is_nil(sr.graded)

    Repo.exists?(query)
  end

  @doc """
  Migrates all section resources for a given section by copying fields from the pinned revision.
  """
  @spec migrate(integer()) :: {:ok, integer()} | {:error, any()}
  def migrate(section_id) do
    base_query = build_migration_base_query(section_id)

    # Build the update query using the base query as a subquery
    update_query =
      from sr in SectionResource,
        join: subquery in subquery(base_query),
        on: sr.resource_id == subquery.resource_id and sr.section_id == ^section_id,
        update: [
          set: [
            project_slug: subquery.project_slug,
            title: subquery.title,
            graded: subquery.graded,
            ai_enabled: subquery.ai_enabled,
            resource_type_id: subquery.resource_type_id,
            revision_slug: subquery.revision_slug,
            purpose: subquery.purpose,
            duration_minutes: subquery.duration_minutes,
            intro_content: subquery.intro_content,
            intro_video: subquery.intro_video,
            poster_image: subquery.poster_image,
            objectives: subquery.objectives,
            relates_to: subquery.relates_to,
            activity_type_id: subquery.activity_type_id,
            revision_id: subquery.revision_id,
            updated_at: fragment("NOW()")
          ]
        ]

    case Repo.update_all(update_query, []) do
      {num_rows, _} -> {:ok, num_rows}
      e -> e
    end
  end

  @doc """
  Migrates only specific section resources by their resource IDs.
  This is more efficient than migrating the entire section resources.
  """
  @spec migrate_specific_resources(integer(), list(integer())) ::
          {:ok, integer()} | {:error, any()}
  def migrate_specific_resources(section_id, resource_ids)
      when is_list(resource_ids) and length(resource_ids) > 0 do
    base_query = build_migration_base_query(section_id, resource_ids)

    # Build the update query using the base query as a subquery
    update_query =
      from sr in SectionResource,
        join: subquery in subquery(base_query),
        on: sr.resource_id == subquery.resource_id and sr.section_id == ^section_id,
        update: [
          set: [
            project_slug: subquery.project_slug,
            title: subquery.title,
            graded: subquery.graded,
            ai_enabled: subquery.ai_enabled,
            resource_type_id: subquery.resource_type_id,
            revision_slug: subquery.revision_slug,
            purpose: subquery.purpose,
            duration_minutes: subquery.duration_minutes,
            intro_content: subquery.intro_content,
            intro_video: subquery.intro_video,
            poster_image: subquery.poster_image,
            objectives: subquery.objectives,
            relates_to: subquery.relates_to,
            activity_type_id: subquery.activity_type_id,
            revision_id: subquery.revision_id,
            updated_at: fragment("NOW()")
          ]
        ]

    case Repo.update_all(update_query, []) do
      {num_rows, _} -> {:ok, num_rows}
      e -> e
    end
  end

  def migrate_specific_resources(_section_id, []), do: {:ok, 0}

  defp build_migration_base_query(section_id, resource_ids \\ nil) do
    filter_by_resource_ids =
      if resource_ids do
        dynamic([_, _, _, r, _], r.resource_id in ^resource_ids)
      else
        true
      end

    from spp in SectionsProjectsPublications,
      join: p in Publication,
      on: p.id == spp.publication_id,
      join: pr in PublishedResource,
      on: pr.publication_id == p.id,
      join: r in Revision,
      on: r.id == pr.revision_id,
      join: proj in Project,
      on: proj.id == spp.project_id,
      where: spp.section_id == ^section_id,
      where: ^filter_by_resource_ids,
      select: %{
        resource_id: r.resource_id,
        project_slug: proj.slug,
        title: r.title,
        graded: r.graded,
        ai_enabled: r.ai_enabled,
        resource_type_id: r.resource_type_id,
        revision_id: r.id,
        revision_slug: r.slug,
        purpose: r.purpose,
        duration_minutes: r.duration_minutes,
        intro_content: r.intro_content,
        intro_video: r.intro_video,
        poster_image: r.poster_image,
        objectives: r.objectives,
        relates_to: r.relates_to,
        activity_type_id: r.activity_type_id
      }
  end
end
