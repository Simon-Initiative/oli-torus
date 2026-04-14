defmodule Oli.InstructorDashboard.DataSnapshot.Projections.ChallengingObjectives do
  @moduledoc """
  Instructor challenging-objectives projection.
  """

  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Helpers

  @meaningful_proficiency_levels ["Low", "Medium", "High"]
  @required_oracles [
    :oracle_instructor_objectives_proficiency,
    :oracle_instructor_scope_resources
  ]

  @spec required_oracles() :: [atom()]
  def required_oracles, do: @required_oracles

  @spec optional_oracles() :: [atom()]
  def optional_oracles, do: []

  @spec derive(Contract.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def derive(%Contract{} = snapshot, _opts) do
    with {:ok, required} <- Helpers.require_oracles(snapshot, @required_oracles) do
      scope = scope_data(snapshot, required)
      objective_payload = Map.get(required, :oracle_instructor_objectives_proficiency, %{})
      objective_rows = objective_rows(objective_payload)
      all_objective_resources = objective_resources(objective_payload)
      scope_filter_by = scope_filter_by(snapshot.scope)

      {state, rows, low_row_count} =
        build_rows(all_objective_resources, objective_rows, scope_filter_by)

      {:ok,
       Helpers.projection_base(snapshot, :challenging_objectives, %{
         state: state,
         has_objectives: objective_rows != [],
         scope: scope,
         rows: rows,
         row_count: low_row_count,
         navigation: %{
           view_all: navigation_for_scope(scope_filter_by)
         }
       })}
    end
  end

  defp build_rows(all_objective_resources, objective_rows, scope_filter_by) do
    objective_rows_by_id = Map.new(objective_rows, &{&1.objective_id, &1})

    qualifying_rows =
      Enum.filter(objective_rows, &(proficiency_mode(&1.proficiency_distribution) == "Low"))

    state =
      cond do
        qualifying_rows != [] -> :populated
        meaningful_data?(objective_rows) -> :empty_low_proficiency
        true -> :no_data
      end

    case qualifying_rows do
      [] ->
        {state, [], 0}

      _ ->
        qualifying_ids = Enum.map(qualifying_rows, & &1.objective_id)
        all_objective_resources_by_id = Map.new(all_objective_resources, &{&1.resource_id, &1})
        effective_children_map = effective_children_map(all_objective_resources)
        parent_map = parent_map(effective_children_map)
        numbering_map = curriculum_numbering_map(all_objective_resources, effective_children_map)

        render_ids =
          qualifying_ids
          |> expand_with_ancestor_ids(parent_map)
          |> Enum.uniq()

        render_id_set = MapSet.new(render_ids)

        section_resources =
          Enum.filter(all_objective_resources, &MapSet.member?(render_id_set, &1.resource_id))

        section_resources_by_id = Map.new(section_resources, &{&1.resource_id, &1})

        rows =
          section_resources
          |> Enum.reject(fn section_resource ->
            case Map.get(parent_map, section_resource.resource_id) do
              nil -> false
              parent_id -> Map.has_key?(section_resources_by_id, parent_id)
            end
          end)
          |> Enum.sort_by(&{&1.numbering_index, &1.resource_id})
          |> Enum.map(
            &build_row(
              &1,
              section_resources_by_id,
              all_objective_resources_by_id,
              effective_children_map,
              objective_rows_by_id,
              numbering_map,
              parent_map,
              scope_filter_by
            )
          )

        {state, rows, length(qualifying_ids)}
    end
  end

  defp scope_data(snapshot, required) do
    scope = snapshot.scope
    scope_resources = Map.get(required, :oracle_instructor_scope_resources, %{})

    %{
      selector: scope_selector(scope),
      label: Map.get(scope_resources, :scope_label, scope_label(scope)),
      course_title: Map.get(scope_resources, :course_title),
      items: Map.get(scope_resources, :items, [])
    }
  end

  defp scope_selector(%{container_type: :container, container_id: container_id}),
    do: "container:#{container_id}"

  defp scope_selector(_scope), do: "course"

  defp scope_label(%{container_type: :course}), do: "Entire Course"
  defp scope_label(%{container_type: :container}), do: "Selected Scope"
  defp scope_label(_scope), do: "Selected Scope"

  defp scope_filter_by(%{container_type: :container, container_id: container_id}),
    do: Integer.to_string(container_id)

  defp scope_filter_by(_scope), do: nil

  defp parent_map(effective_children_map) do
    Enum.reduce(effective_children_map, %{}, fn {resource_id, child_ids}, acc ->
      Enum.reduce(child_ids, acc, fn child_id, child_acc ->
        Map.put(child_acc, child_id, resource_id)
      end)
    end)
  end

  defp effective_children_map(section_resources) do
    Enum.into(section_resources, %{}, fn section_resource ->
      {section_resource.resource_id, section_resource.children || []}
    end)
  end

  defp expand_with_ancestor_ids(ids, parent_map) do
    ids
    |> MapSet.new()
    |> then(fn expanded_ids ->
      Enum.reduce(ids, expanded_ids, fn objective_id, acc ->
        collect_ancestor_ids(objective_id, parent_map, acc)
      end)
    end)
    |> MapSet.to_list()
  end

  defp collect_ancestor_ids(objective_id, parent_map, acc) do
    case Map.get(parent_map, objective_id) do
      nil ->
        acc

      parent_id ->
        if MapSet.member?(acc, parent_id) do
          acc
        else
          collect_ancestor_ids(parent_id, parent_map, MapSet.put(acc, parent_id))
        end
    end
  end

  defp build_row(
         section_resource,
         section_resources_by_id,
         all_objective_resources_by_id,
         effective_children_map,
         objective_rows_by_id,
         numbering_map,
         parent_map,
         scope_filter_by,
         visited_ids \\ MapSet.new()
       ) do
    if MapSet.member?(visited_ids, section_resource.resource_id) do
      nil
    else
      visited_ids = MapSet.put(visited_ids, section_resource.resource_id)
      objective_row = Map.get(objective_rows_by_id, section_resource.resource_id)

      child_ids =
        effective_children_map
        |> Map.get(section_resource.resource_id, [])
        |> Enum.filter(&Map.has_key?(section_resources_by_id, &1))

      parent_id = Map.get(parent_map, section_resource.resource_id)

      parent_title =
        all_objective_resources_by_id
        |> Map.get(parent_id)
        |> case do
          nil -> nil
          parent -> parent.title
        end

      children =
        child_ids
        |> Enum.map(&Map.fetch!(section_resources_by_id, &1))
        |> Enum.sort_by(&{&1.numbering_index, &1.resource_id})
        |> Enum.map(
          &build_row(
            &1,
            section_resources_by_id,
            all_objective_resources_by_id,
            effective_children_map,
            objective_rows_by_id,
            numbering_map,
            parent_map,
            scope_filter_by,
            visited_ids
          )
        )
        |> Enum.reject(&is_nil/1)

      %{
        objective_id: section_resource.resource_id,
        parent_objective_id: parent_id,
        parent_title: parent_title,
        title: objective_title(section_resource, objective_row),
        row_type: if(is_nil(parent_id), do: :objective, else: :subobjective),
        numbering: Map.get(numbering_map, section_resource.resource_id),
        numbering_index: section_resource.numbering_index,
        numbering_level: section_resource.numbering_level,
        proficiency_label: proficiency_label(objective_row),
        proficiency_distribution: proficiency_distribution(objective_row),
        has_children: children != [],
        children: children,
        navigation:
          navigation_for(
            section_resource.resource_id,
            parent_id,
            if(is_nil(parent_id), do: :objective, else: :subobjective),
            scope_filter_by
          )
      }
    end
  end

  defp navigation_for(objective_id, nil, :objective, scope_filter_by) do
    navigation_for_scope(scope_filter_by)
    |> Map.merge(%{
      objective_id: objective_id
    })
  end

  defp navigation_for(objective_id, parent_objective_id, :subobjective, scope_filter_by) do
    navigation_for_scope(scope_filter_by)
    |> Map.merge(%{
      objective_id: parent_objective_id || objective_id,
      subobjective_id: objective_id
    })
  end

  defp navigation_for_scope(nil), do: %{navigation_source: "challenging_objectives_tile"}

  defp navigation_for_scope(filter_by),
    do: %{filter_by: filter_by, navigation_source: "challenging_objectives_tile"}

  defp curriculum_numbering_map(all_objective_resources, effective_children_map) do
    all_objective_resources_by_id = Map.new(all_objective_resources, &{&1.resource_id, &1})
    parent_map = parent_map(effective_children_map)

    all_objective_resources
    |> Enum.reject(&Map.has_key?(parent_map, &1.resource_id))
    |> Enum.sort_by(&{&1.numbering_index, &1.resource_id})
    |> assign_curriculum_numbering(
      %{},
      all_objective_resources_by_id,
      effective_children_map,
      nil,
      MapSet.new()
    )
  end

  defp assign_curriculum_numbering(
         resources,
         numbering_map,
         all_objective_resources_by_id,
         effective_children_map,
         prefix,
         visited_ids
       ) do
    resources
    |> Enum.reject(&MapSet.member?(visited_ids, &1.resource_id))
    |> Enum.with_index(1)
    |> Enum.reduce(numbering_map, fn {resource, index}, acc ->
      numbering =
        case prefix do
          nil -> Integer.to_string(index)
          prefix -> "#{prefix}.#{index}"
        end

      visited_ids = MapSet.put(visited_ids, resource.resource_id)

      child_resources =
        effective_children_map
        |> Map.get(resource.resource_id, [])
        |> Enum.map(&Map.get(all_objective_resources_by_id, &1))
        |> Enum.reject(&is_nil/1)
        |> Enum.sort_by(&{&1.numbering_index, &1.resource_id})

      updated_acc = Map.put(acc, resource.resource_id, numbering)

      assign_curriculum_numbering(
        child_resources,
        updated_acc,
        all_objective_resources_by_id,
        effective_children_map,
        numbering,
        visited_ids
      )
    end)
  end

  defp objective_title(section_resource, nil), do: section_resource.title
  defp objective_title(_section_resource, objective_row), do: objective_row.title

  defp proficiency_label(nil), do: nil

  defp proficiency_label(objective_row),
    do: proficiency_mode(objective_row.proficiency_distribution)

  defp proficiency_distribution(nil), do: %{}
  defp proficiency_distribution(objective_row), do: objective_row.proficiency_distribution

  defp meaningful_data?(objective_rows) do
    Enum.any?(objective_rows, fn row ->
      row.proficiency_distribution
      |> normalize_proficiency_distribution()
      |> then(fn proficiency_distribution ->
        Enum.any?(
          @meaningful_proficiency_levels,
          &(Map.get(proficiency_distribution, &1, 0) > 0)
        )
      end)
    end)
  end

  defp proficiency_mode(proficiency_distribution) when proficiency_distribution in [%{}, nil],
    do: "Not enough data"

  defp proficiency_mode(proficiency_distribution) do
    proficiency_distribution
    |> Enum.map(fn {label, count} ->
      {label, count, proficiency_ordinal(label)}
    end)
    |> Enum.sort_by(fn {_label, _count, ordinal} -> ordinal end)
    |> Enum.max_by(fn {_label, count, _ordinal} -> count end, fn -> {"Not enough data", 0, 3} end)
    |> elem(0)
  end

  defp proficiency_ordinal(label) do
    case String.downcase(label) do
      "low" -> 0
      "medium" -> 1
      "high" -> 2
      _ -> 3
    end
  end

  defp normalize_proficiency_distribution(proficiency_distribution)
       when proficiency_distribution in [%{}, nil],
       do: %{}

  defp normalize_proficiency_distribution(proficiency_distribution) do
    Enum.into(proficiency_distribution, %{}, fn {label, count} ->
      {normalize_proficiency_label(label), count}
    end)
  end

  defp normalize_proficiency_label(label) when is_binary(label) do
    case String.downcase(label) do
      "low" -> "Low"
      "medium" -> "Medium"
      "high" -> "High"
      other -> other
    end
  end

  defp normalize_proficiency_label(label), do: label

  defp objective_rows(%{objective_rows: rows}) when is_list(rows), do: rows
  defp objective_rows(rows) when is_list(rows), do: rows
  defp objective_rows(_), do: []

  defp objective_resources(%{objective_resources: resources}) when is_list(resources),
    do: resources

  defp objective_resources(_), do: []
end
