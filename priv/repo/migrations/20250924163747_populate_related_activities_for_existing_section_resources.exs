defmodule Oli.Repo.Migrations.PopulateRelatedActivitiesForExistingSectionResources do
  use Ecto.Migration
  import Ecto.Query

  def get_env_as_boolean(key, default \\ nil) do
    System.get_env(key, default)
    |> String.downcase()
    |> String.trim()
    |> case do
      "true" -> true
      _ -> false
    end
  end

  def up do
    if get_env_as_boolean("SKIP_POPULATE_RELATED_ACTIVITIES_MIGRATION", "false") do
      IO.puts("Skipping PopulateRelatedActivitiesForExistingSectionResources migration")
      :ok
    else
      objective_type_id = 4
      activity_type_id = 3

      # Process sections in batches to avoid memory issues
      batch_size = 100

      # Get total count for progress tracking
      total_sections = repo().aggregate(from(s in "sections"), :count, :id)
      IO.puts("Populating related_activities for #{total_sections} sections...")

      # Process sections in batches
      process_sections_in_batches(0, batch_size, objective_type_id, activity_type_id)

      IO.puts("Completed populating related_activities field")
    end
  end

  def down do
    # Reset related_activities to empty arrays
    repo().update_all(from(sr in "section_resources"), set: [related_activities: []])
  end

  defp process_sections_in_batches(offset, batch_size, objective_type_id, activity_type_id) do
    sections =
      from(s in "sections",
        select: %{id: s.id, slug: s.slug},
        limit: ^batch_size,
        offset: ^offset
      )
      |> repo().all()

    case sections do
      [] ->
        :done

      sections ->
        Enum.each(sections, fn section ->
          populate_related_activities_for_section(section, objective_type_id, activity_type_id)
        end)

        # Process next batch
        process_sections_in_batches(
          offset + batch_size,
          batch_size,
          objective_type_id,
          activity_type_id
        )
    end
  end

  defp populate_related_activities_for_section(section, objective_type_id, activity_type_id) do
    IO.puts("Processing section #{section.slug} (ID: #{section.id})...")

    # Get all objectives in this section
    objectives =
      from(rev in section_resource_revisions(section.slug),
        where: rev.deleted == false and rev.resource_type_id == ^objective_type_id,
        select: %{resource_id: rev.resource_id}
      )
      |> repo().all()

    objective_ids = Enum.map(objectives, & &1.resource_id)
    objective_id_set = MapSet.new(objective_ids)

    # Get all activities with objectives in this section
    activities_with_objectives =
      from(rev in section_resource_revisions(section.slug),
        where:
          rev.deleted == false and
            rev.resource_type_id == ^activity_type_id and
            not is_nil(rev.objectives),
        select: %{resource_id: rev.resource_id, objectives: rev.objectives}
      )
      |> repo().all()

    # Calculate related activities for each objective
    related_activities_map =
      activities_with_objectives
      |> Enum.reduce(%{}, fn activity, acc ->
        case activity.objectives do
          objectives_map when is_map(objectives_map) ->
            # Extract all unique objective IDs from this activity
            activity_objective_ids =
              objectives_map
              |> Enum.flat_map(fn {_part_id, obj_list} ->
                case obj_list do
                  obj_list when is_list(obj_list) and length(obj_list) > 0 -> obj_list
                  _ -> []
                end
              end)
              |> MapSet.new()

            # Find intersection with our objective set
            matching_objective_ids = MapSet.intersection(activity_objective_ids, objective_id_set)

            # Add this activity to each matching objective's related activities list
            Enum.reduce(matching_objective_ids, acc, fn obj_id, acc ->
              Map.update(acc, obj_id, [activity.resource_id], &(&1 ++ [activity.resource_id]))
            end)

          _ ->
            acc
        end
      end)

    # Batch update section_resources with related_activities using a single query
    if not Enum.empty?(objectives) do
      # Build the update values for each section resource
      update_values =
        objectives
        |> Enum.map(fn objective ->
          related_activity_ids = Map.get(related_activities_map, objective.resource_id, [])
          {objective.resource_id, related_activity_ids}
        end)
        |> Enum.into(%{})

      # Use raw SQL with a CASE statement for efficient batch update
      case_statements =
        update_values
        |> Enum.map(fn {resource_id, activity_ids} ->
          # Convert activity IDs to PostgreSQL array format
          array_literal =
            if Enum.empty?(activity_ids) do
              "ARRAY[]::bigint[]"
            else
              "ARRAY[#{Enum.join(activity_ids, ",")}]::bigint[]"
            end

          "WHEN resource_id = #{resource_id} THEN #{array_literal}"
        end)
        |> Enum.join(" ")

      resource_ids = Map.keys(update_values)

      update_query = """
        UPDATE section_resources
        SET related_activities = CASE #{case_statements} END
        WHERE section_id = $1 AND resource_id = ANY($2)
      """

      repo().query(update_query, [section.id, resource_ids])
    end
  end

  defp section_resource_revisions(section_slug) do
    from(rev in "revisions",
      join: sr in "section_resources",
      on: sr.resource_id == rev.resource_id,
      join: s in "sections",
      on: s.id == sr.section_id,
      join: spp in "sections_projects_publications",
      on: spp.section_id == s.id,
      join: pr in "published_resources",
      on: pr.publication_id == spp.publication_id and pr.resource_id == rev.resource_id,
      where: s.slug == ^section_slug and pr.revision_id == rev.id
    )
  end
end
