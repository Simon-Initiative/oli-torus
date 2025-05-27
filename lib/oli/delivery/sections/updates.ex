defmodule Oli.Delivery.Sections.Updates do
  require Logger
  import Ecto.Query, warn: false

  alias Oli.Delivery.Sections.MinimalHierarchy
  alias Oli.Repo
  alias Oli.Delivery.Sections
  alias Oli.Publishing
  alias Oli.Resources.ResourceType
  alias Oli.Publishing.Publications.PublicationDiff
  alias Oli.Delivery.Updates.Broadcaster
  alias Oli.Delivery.Sections.PostProcessing
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Resources.Numbering

  alias Oli.Delivery.Sections.{
    Section,
    SectionResource
  }

  @section_resources_on_conflict {:replace_all_except,
                                  [
                                    :inserted_at,
                                    :scoring_strategy_id,
                                    :scheduling_type,
                                    :manually_scheduled,
                                    :start_date,
                                    :end_date,
                                    :collab_space_config,
                                    :explanation_strategy,
                                    :max_attempts,
                                    :retake_mode,
                                    :assessment_mode,
                                    :batch_scoring,
                                    :replacement_strategy,
                                    :password,
                                    :late_submit,
                                    :late_start,
                                    :time_limit,
                                    :grace_period,
                                    :review_submission,
                                    :feedback_mode,
                                    :feedback_scheduled_date
                                  ]}

  @doc """
  Gracefully applies the specified publication update to a given section by leaving the existing
  curriculum and section modifications in-tact while applying the structural changes that
  occurred between the old and new publication.

  This implementation makes the assumption that a resource_id is unique within a curriculum.
  That is, a resource can only allowed to be added once in a single location within a curriculum.
  This makes it simpler to apply changes to the existing curriculum but if necessary, this implementation
  could be extended to not just apply the changes to the first node found that contains the changed resource,
  but any/all nodes in the hierarchy which reference the changed resource.
  """
  def apply_publication_update(
        %Section{id: section_id} = section,
        publication_id
      ) do
    Broadcaster.broadcast_update_progress(section.id, publication_id, 0)

    new_publication = Publishing.get_publication!(publication_id)
    project = Oli.Repo.get(Oli.Authoring.Course.Project, new_publication.project_id)
    current_publication = Sections.get_current_publication(section_id, project.id)

    result =
      Oli.Repo.transaction(fn ->
        case do_update(section, project.id, current_publication, new_publication) do
          {:ok, _} ->
            do_post_processing_steps(section, project)

          e ->
            Oli.Repo.rollback(e)
        end
      end)

    case result do
      {:ok, _} ->
        Oli.Delivery.Sections.SectionCache.clear(section.slug)

        Oli.Delivery.DepotCoordinator.refresh(
          Oli.Delivery.Sections.SectionResourceDepot.depot_desc(),
          section_id,
          Oli.Delivery.Sections.SectionResourceDepot
        )

        Broadcaster.broadcast_update_progress(section.id, new_publication.id, :complete)

      _ ->
        Broadcaster.broadcast_update_progress(section.id, new_publication.id, 0)
    end

    result
  end

  defp do_post_processing_steps(section, project) do
    # For a section based on this project, update the has_experiments in the section to match that
    # setting in the project.
    if section.base_project_id == project.id and
         project.has_experiments != section.has_experiments do
      Oli.Delivery.Sections.update_section(section, %{has_experiments: project.has_experiments})
    end

    PostProcessing.apply(section, :all)
  end

  # Implements the logic to determine *how* to apply the update to the course section,
  # taking into account the update type (minor / major) and the source of the section
  # (project / product)
  defp do_update(section, project_id, current_publication, new_publication) do
    case Publishing.get_publication_diff(current_publication, new_publication) do
      %PublicationDiff{classification: :minor} = diff ->
        do_minor_update(diff, section, project_id, new_publication)

      %PublicationDiff{classification: :major} = diff ->
        cond do
          # Case 1: The course section is based on this project, but is not a product and is not seeded from a product
          section.base_project_id == project_id and section.type == :enrollable and
              is_nil(section.blueprint_id) ->
            do_major_update(diff, section, project_id, current_publication, new_publication)

          # Case 2: The course section is based on this project and was seeded from a product
          section.base_project_id == project_id and !is_nil(section.blueprint_id) ->
            if section.blueprint.apply_major_updates do
              do_major_update(diff, section, project_id, current_publication, new_publication)
            else
              do_minor_update(diff, section, project_id, new_publication)
            end

          # Case 3: The course section is a product based on this project
          section.base_project_id == project_id and section.type == :blueprint ->
            do_minor_update(diff, section, project_id, new_publication)

          # Case 4: The course section is not based on this project (but it remixes some materials from project)
          true ->
            do_minor_update(diff, section, project_id, new_publication)
        end
    end
  end

  # Perform a MINOR update:
  # 1. Add SR records for all resource types that were added in this pub, except for containers
  # 2. Delete SR records for all resource types that were deleted EXCEPT for pages and containers.
  #       We cannot delete page SR records because we may be applying a major update as a minor
  #       update - and we need that page to stay present if we are not processing the removal from
  #       the container
  # 3. Move forard the SPP records to the new publication
  # 4. Cull unreachable pages.
  defp do_minor_update(%PublicationDiff{} = diff, section, project_id, new_publication) do
    mark = Oli.Timing.mark()

    container_type_id = Oli.Resources.ResourceType.get_id_by_type("container")
    page_type_id = Oli.Resources.ResourceType.get_id_by_type("page")

    case diff
         |> filter_for_revisions(:added, fn r -> r.resource_type_id != container_type_id end)
         |> bulk_create_section_resources(section, project_id) do
      {:ok, _} ->
        diff
        |> filter_for_revisions(:deleted, fn r ->
          r.resource_type_id != container_type_id and
            r.resource_type_id != page_type_id
        end)
        |> bulk_delete_section_resources(section)

        Sections.update_section_project_publication(section, project_id, new_publication.id)

        cull_unreachable_pages(section, diff)

        Logger.info(
          "perform_update.MINOR: section[#{section.slug}] #{Oli.Timing.elapsed(mark) / 1000 / 1000}ms"
        )

        {:ok, :ok}

      {:error, _} ->
        {:error, :unexpected_count}
    end
  end

  def ensure_section_resource_exists(_section_slug, nil), do: {:ok, :exists}

  def ensure_section_resource_exists(section_slug, resource_id) do
    case Oli.Publishing.DeliveryResolver.from_resource_id(section_slug, resource_id) do
      nil ->
        # Fetch the published revision of this revision along with section and project id
        query =
          Oli.Delivery.Sections.SectionsProjectsPublications
          |> join(:left, [spp], pr in Oli.Publishing.PublishedResource,
            on: pr.publication_id == spp.publication_id
          )
          |> join(:left, [_, pr], rev in Oli.Resources.Revision, on: rev.id == pr.revision_id)
          |> join(:left, [spp, _, _], s in Oli.Delivery.Sections.Section,
            on: s.id == spp.section_id
          )
          |> where([spp, pr, rev, s], s.slug == ^section_slug and pr.resource_id == ^resource_id)
          |> select([spp, _pr, rev, section], %{
            revision: rev,
            section: section,
            project_id: spp.project_id
          })
          |> limit(1)

        case Repo.one(query) do
          nil ->
            {:error, :not_found}

          # Create the section resource record, using the exact same logic used in creating SR records
          # during publication application
          %{revision: revision, section: section, project_id: project_id} ->
            bulk_create_section_resources([revision], section, project_id)
        end

      _ ->
        {:ok, :exists}
    end
  end

  # Add all and delete all SR records that were added/deleted in the publication diff
  defp add_remove_srs(%PublicationDiff{} = diff, section, project_id) do
    case diff
         |> filter_for_revisions(:added, fn _r -> true end)
         |> bulk_create_section_resources(section, project_id) do
      {:ok, _} ->
        diff
        |> filter_for_revisions(:deleted, fn _r -> true end)
        |> bulk_delete_section_resources(section)

        {:ok, :ok}

      {:error, _} ->
        {:error, :unexpected_count}
    end
  end

  # For a publication diff and a desired type (:added, :deleted) return
  # all of the revisions that pass the supplied filter func
  defp filter_for_revisions(%PublicationDiff{} = diff, desired_type, filter_fn) do
    Map.filter(diff.changes, fn {_k, {this_type, _}} -> this_type == desired_type end)
    |> Map.values()
    |> Enum.map(fn {_, %{revision: r}} -> r end)
    |> Enum.filter(filter_fn)
  end

  # Bulk create a collection of Section Resource records (SRs) for a collection
  # of revisions
  defp bulk_create_section_resources(revisions, section, project_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    placeholders = %{timestamp: now}

    section_resource_rows =
      Enum.map(revisions, fn r ->
        %{
          resource_id: r.resource_id,
          project_id: project_id,
          section_id: section.id,
          children: nil,
          scoring_strategy_id: r.scoring_strategy_id,
          slug: Oli.Utils.Slug.generate("section_resources", r.title),
          inserted_at: {:placeholder, :timestamp},
          updated_at: {:placeholder, :timestamp},
          collab_space_config: r.collab_space_config,
          batch_scoring: r.batch_scoring,
          replacement_strategy: r.replacement_strategy,
          max_attempts:
            if is_nil(r.max_attempts) do
              0
            else
              r.max_attempts
            end,
          retake_mode: r.retake_mode,
          assessment_mode: r.assessment_mode
        }
      end)

    expected_count = Enum.count(section_resource_rows)

    case Oli.Utils.Database.batch_insert_all(SectionResource, section_resource_rows,
           placeholders: placeholders,
           on_conflict: @section_resources_on_conflict,
           conflict_target: [:section_id, :resource_id]
         ) do
      {^expected_count, _} -> {:ok, Enum.count(section_resource_rows)}
      _ -> {:error, :unexpected_count}
    end
  end

  # Bulk delete a collection of SR records that match a collection of revisions
  defp bulk_delete_section_resources(revisions, %Section{id: section_id}) do
    resource_ids = Enum.map(revisions, & &1.resource_id)

    from(sr in SectionResource,
      where: sr.section_id == ^section_id and sr.resource_id in ^resource_ids
    )
    |> Repo.delete_all()
  end

  # Do a MAJOR update
  # 1. Add / Remove all SR records per the publication diff. This step is different than minor
  #       updates because we add and remove containers as well
  # 2. Move forward the SPP record to the new publication id
  # 3. Update contain children - this is the key step that differentiates major from minor
  #       updates where we update the :children attr of the containers to change the hiearchy
  # 4. Rebuild previous next index, contained pages, contained objective
  defp do_major_update(
         %PublicationDiff{} = diff,
         section,
         project_id,
         prev_publication,
         new_publication
       ) do
    mark = Oli.Timing.mark()

    add_remove_srs(diff, section, project_id)
    Sections.update_section_project_publication(section, project_id, new_publication.id)

    with {:ok, _} <- update_container_children(section, prev_publication, new_publication),
         {:ok, _} <- cull_unreachable_pages(section, diff),
         {:ok, _} <- Oli.Delivery.PreviousNextIndex.rebuild(section),
         {:ok, _} <- Sections.rebuild_contained_pages(section),
         {:ok, _} <- Sections.rebuild_contained_objectives(section) do
      Logger.info(
        "perform_update.MAJOR: section[#{section.slug}] #{Oli.Timing.elapsed(mark) / 1000 / 1000}ms"
      )

      renumber_hierarchy(section)

      {:ok, :ok}
    else
      e -> e
    end
  end

  # Rebuild the numberin the hierarchy, and issue a bulk update to set those
  # new values in the section resource records
  defp renumber_hierarchy(section) do
    {hierarchy, _} =
      MinimalHierarchy.full_hierarchy(section.slug)
      |> Numbering.renumber_hierarchy()

    section_resource_rows =
      collapse_section_hierarchy(hierarchy, section.id, [])
      |> Enum.filter(fn sr -> sr.numbering_level != 0 end)

    {values, params, _} =
      Enum.reduce(section_resource_rows, {[], [], 0}, fn sr, {values, params, i} ->
        {
          values ++ ["($#{i + 1}::bigint, $#{i + 2}::bigint, $#{i + 3}::bigint)"],
          params ++ [sr.id, sr.numbering_level, sr.numbering_index],
          i + 3
        }
      end)

    values = Enum.join(values, ",")

    sql = """
      UPDATE section_resources
      SET
        numbering_level = batch_values.numbering_level,
        numbering_index = batch_values.numbering_index
      FROM (
          VALUES
          #{values}
      ) AS batch_values (id, numbering_level, numbering_index)
      WHERE section_resources.id = batch_values.id
    """

    Ecto.Adapters.SQL.query(Oli.Repo, sql, params)
  end

  defp collapse_section_hierarchy(
         %HierarchyNode{
           finalized: true,
           numbering: numbering,
           section_resource: %SectionResource{id: id},
           children: children
         },
         section_id,
         section_resources \\ []
       ) do
    section_resources =
      Enum.reduce(children, section_resources, fn child, section_resources ->
        section_resources ++ collapse_section_hierarchy(child, section_id)
      end)

    section_resource = %{
      numbering_index: numbering.index,
      numbering_level: numbering.level,
      id: id
    }

    [section_resource | section_resources]
  end

  defp cull_unreachable_pages(section, %PublicationDiff{to_pub: publication, all_links: all_links}) do
    section_id = section.id

    map =
      Oli.Delivery.Sections.MinimalHierarchy.full_hierarchy(section.slug)
      |> Oli.Delivery.Hierarchy.flatten()
      |> Enum.reduce(%{}, fn s, m -> Map.put(m, s.section_resource.id, s) end)

    hierarchy_ids =
      Map.values(map)
      |> Enum.map(fn s ->
        [
          s.section_resource.resource_id
          | Enum.map(s.children, fn c ->
              Map.get(map, c.section_resource.id).section_resource.resource_id
            end)
        ]
      end)
      |> List.flatten()

    project = Oli.Authoring.Course.get_project!(publication.project_id)

    # Determine the unreachable page resource ids, but taking into account if
    # EITHER the project or the section has a required survey resource id to
    # ensure that it never gets culled.
    additional_excluded_ids =
      [section.required_survey_resource_id, project.required_survey_resource_id]
      |> Enum.filter(&(&1 != nil))
      |> MapSet.new()

    # Determine the unreachable page resource ids based strictly on hierarchy navigability
    unreachable_page_resource_ids =
      Oli.Delivery.Sections.determine_unreachable_pages(
        [publication.id],
        hierarchy_ids,
        all_links
      )

      # But filter out any additional excluded resource ids (like required surveys)
      |> Enum.filter(fn id -> !Enum.member?(additional_excluded_ids, id) end)

    project_id = publication.project_id

    case unreachable_page_resource_ids do
      [] ->
        {:ok, true}

      _ ->
        from(sr in SectionResource,
          where:
            sr.project_id == ^project_id and
              sr.section_id == ^section_id and
              sr.resource_id in ^unreachable_page_resource_ids
        )
        |> Repo.delete_all()

        {:ok, true}
    end
  end

  defp update_container_children(section, prev_publication, new_publication) do
    container = ResourceType.id_for_container()

    prev_published_resources_map =
      MinimalHierarchy.published_resources_map(prev_publication.id)

    new_published_resources_map =
      MinimalHierarchy.published_resources_map(new_publication.id)

    # get all section resources including freshly minted ones
    section_resources = Sections.get_section_resources(section.id)

    # build mappings from section_resource_id to resource_id and the inverse
    {sr_id_to_resource_id, resource_id_to_sr_id} =
      section_resources
      |> Enum.reduce({%{}, %{}}, fn %SectionResource{id: id, resource_id: resource_id},
                                    {sr_id_to_resource_id, resource_id_to_sr_id} ->
        {Map.put(sr_id_to_resource_id, id, resource_id),
         Map.put(resource_id_to_sr_id, resource_id, id)}
      end)

    # For all container section resources in the course project whose children attribute differs
    # from the new publication’s container children, execute the three way merge algorithm
    merged_section_resources =
      section_resources
      |> Enum.map(fn section_resource ->
        %SectionResource{
          resource_id: resource_id,
          children: current_children
        } = section_resource

        prev_published_resource = prev_published_resources_map[resource_id]

        is_container? =
          case prev_published_resource do
            %{resource_type_id: ^container} ->
              true

            _ ->
              false
          end

        if is_container? or is_nil(current_children) do
          new_published_resource = new_published_resources_map[resource_id]
          new_children = new_published_resource.children

          updated_section_resource =
            case current_children do
              nil ->
                # this section resource was just created so it can assume the newly published value
                %SectionResource{
                  section_resource
                  | children: Enum.map(new_children, &resource_id_to_sr_id[&1])
                }

              current_children ->
                # ensure we are comparing resource_ids to resource_ids (and not section_resource_ids)
                # by translating the current section_resource children ids to resource_ids
                current_children_resource_ids =
                  Enum.map(current_children, &sr_id_to_resource_id[&1])

                # check if the children resource_ids have diverged from the new value
                if current_children_resource_ids != new_children do
                  # There is a merge conflict between the current section resource and the new published resource.
                  # Use the AIRRO three way merge algorithm to resolve
                  base = prev_published_resource.children
                  source = new_published_resource.children
                  target = current_children_resource_ids

                  case Oli.Publishing.Updating.Merge.merge(base, source, target) do
                    {:ok, merged} ->
                      %SectionResource{
                        section_resource
                        | children: Enum.map(merged, &resource_id_to_sr_id[&1])
                      }

                    {:no_change} ->
                      section_resource
                  end
                else
                  section_resource
                end
            end

          Sections.clean_children(
            updated_section_resource,
            sr_id_to_resource_id,
            new_published_resources_map
          )
        else
          section_resource
        end
      end)

    # Upsert all merged section resource records. Some of these records may have just been created
    # and some may not have been changed, but that's okay we will just update them again. There
    # isn't a lot of them as these are just the container resources.
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    placeholders = %{timestamp: now}

    section_resource_rows =
      merged_section_resources
      |> Enum.map(fn section_resource ->
        %{
          SectionResource.to_map(section_resource)
          | updated_at: {:placeholder, :timestamp}
        }
      end)

    expected_count = Enum.count(section_resource_rows)

    case Oli.Utils.Database.batch_insert_all(SectionResource, section_resource_rows,
           placeholders: placeholders,
           on_conflict: @section_resources_on_conflict,
           conflict_target: [:section_id, :resource_id]
         ) do
      {^expected_count, _} -> {:ok, expected_count}
      _ -> {:error, :unexpected_count}
    end
  end
end
