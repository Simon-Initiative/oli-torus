defmodule Oli.Delivery.Sections.SectionResourceMigration do
  alias Oli.Repo
  import Ecto.Query
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Sections.SectionsProjectsPublications
  alias Oli.Publishing.Publications.Publication
  alias Oli.Publishing.PublishedResource
  alias Oli.Resources.Revision
  alias Oli.Authoring.Course.Project

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
