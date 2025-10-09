defmodule Oli.Delivery.Sections.PostProcessing do
  import Ecto.Query, warn: false
  require Logger
  alias Oli.Repo

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.ResourceType

  @type options :: [option]
  @type option :: :all | :discussions | :explorations | :deliberate_practice | :related_activities

  @page_type_id ResourceType.id_for_page()
  @objective_type_id ResourceType.id_for_objective()
  @activity_type_id ResourceType.id_for_activity()
  @all_actions [:discussions, :explorations, :deliberate_practice, :related_activities]

  @spec apply(Section.t(), options() | option()) :: Section.t()
  def apply(section, actions \\ []) do
    actions =
      case actions do
        :all -> @all_actions
        action when action in @all_actions -> List.wrap(action)
        actions -> actions
      end

    changes =
      Enum.reduce(Enum.uniq(actions), %{}, fn action, acc ->
        case action do
          :discussions ->
            Map.put(acc, :contains_discussions, maybe_update_contains_discusssions(section))

          :explorations ->
            Map.put(acc, :contains_explorations, maybe_update_contains_explorations(section))

          :deliberate_practice ->
            Map.put(acc, :contains_deliberate_practice, contains_deliberate_practice(section))

          :related_activities ->
            populate_related_activities(section)
            acc

          _ ->
            acc
        end
      end)

    Sections.update_section!(section, changes)
  end

  # Updates contains_discussions flag if an active discussion is present.
  @spec maybe_update_contains_discusssions(Section.t()) :: boolean()
  defp maybe_update_contains_discusssions(section) do
    from(s in Section,
      join: sr in assoc(s, :section_resources),
      where: s.id == ^section.id,
      where: fragment("?->>'status' = ?", sr.collab_space_config, "enabled"),
      limit: 1,
      select: sr.id
    )
    |> Repo.exists?()
  end

  @spec maybe_update_contains_explorations(Section.t()) :: boolean()
  defp maybe_update_contains_explorations(section) do
    from([rev: rev] in base_query(section), where: rev.purpose == :application)
    |> Repo.exists?()
  end

  @spec contains_deliberate_practice(Section.t()) :: boolean()
  defp contains_deliberate_practice(section) do
    from([rev: rev] in base_query(section), where: rev.purpose == :deliberate_practice)
    |> Repo.exists?()
  end

  defp base_query(section) do
    from([sr: sr, rev: rev] in DeliveryResolver.section_resource_revisions(section.slug),
      where: rev.deleted == false,
      where: rev.resource_type_id == ^@page_type_id,
      limit: 1,
      select: rev.id
    )
  end

  _docp = """
  Populates the related_activities field for all objective resources in a section.

  This function establishes bidirectional relationships between objectives and activities
  by analyzing which activities reference each objective in their objectives field.

  Steps:
  1. Fetches objectives: Gets all objective resources in a section
  2. Fetches activities: Gets all activity resources that have objectives defined
  3. Maps relationships: For each activity, extracts its objective IDs and finds which section objectives it relates to
  4. Batch updates: Uses raw SQL with CASE statements to update section_resources.related_activities field
  """

  @spec populate_related_activities(Section.t()) :: :ok | :error
  defp populate_related_activities(section) do
    # Get all objectives in this section
    objectives =
      from([rev: rev, sr: sr] in DeliveryResolver.section_resource_revisions(section.slug),
        where: rev.deleted == false and rev.resource_type_id == ^@objective_type_id,
        select: %{resource_id: rev.resource_id, section_resource_id: sr.id}
      )
      |> Repo.all()

    objective_ids = Enum.map(objectives, & &1.resource_id)
    objective_id_set = MapSet.new(objective_ids)

    # Get all activities with objectives in this section
    activities_with_objectives =
      from([rev: rev, sr: sr] in DeliveryResolver.section_resource_revisions(section.slug),
        where:
          rev.deleted == false and
            rev.resource_type_id == ^@activity_type_id and
            not is_nil(rev.objectives),
        select: %{resource_id: rev.resource_id, objectives: rev.objectives}
      )
      |> Repo.all()

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
      section_resource_ids = Enum.map(objectives, & &1.section_resource_id)

      # Build the update values for each section resource
      update_values =
        objectives
        |> Enum.map(fn objective ->
          related_activity_ids = Map.get(related_activities_map, objective.resource_id, [])
          {objective.section_resource_id, related_activity_ids}
        end)
        |> Enum.into(%{})

      # Use raw SQL with a CASE statement for efficient batch update
      case_statements =
        update_values
        |> Enum.map(fn {section_resource_id, activity_ids} ->
          # Convert activity IDs to PostgreSQL array format
          array_literal =
            if Enum.empty?(activity_ids) do
              "ARRAY[]::bigint[]"
            else
              "ARRAY[#{Enum.join(activity_ids, ",")}]::bigint[]"
            end

          "WHEN id = #{section_resource_id} THEN #{array_literal}"
        end)
        |> Enum.join(" ")

      update_query = """
        UPDATE section_resources
        SET related_activities = CASE #{case_statements} END
        WHERE id = ANY($1)
      """

      case Repo.query(update_query, [section_resource_ids]) do
        {:ok, _result} ->
          :ok

        {:error, error} ->
          Logger.error(
            "[PostProcessing] Failed to update related_activities for section #{section.slug}: #{inspect(error)}"
          )

          :error
      end
    else
      :ok
    end
  end
end
