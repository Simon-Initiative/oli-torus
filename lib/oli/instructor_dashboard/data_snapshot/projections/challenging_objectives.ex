defmodule Oli.InstructorDashboard.DataSnapshot.Projections.ChallengingObjectives do
  @moduledoc """
  Instructor challenging-objectives projection.
  """

  import Ecto.Query, warn: false

  require Logger

  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Helpers
  alias Oli.Repo
  alias Oli.Resources.Revision

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
      section_id = snapshot.metadata.dashboard_context_id
      scope = scope_data(snapshot, required, section_id)
      objective_rows = Map.get(required, :oracle_instructor_objectives_proficiency, [])
      scope_filter_by = scope_filter_by(snapshot.scope)
      {state, rows, low_row_count} = build_rows(section_id, objective_rows, scope_filter_by)

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

  defp build_rows(section_id, objective_rows, scope_filter_by) do
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
        all_objective_resources = SectionResourceDepot.objectives(section_id)
        all_objective_resources_by_id = Map.new(all_objective_resources, &{&1.resource_id, &1})
        effective_children_map = effective_children_map(all_objective_resources)
        parent_map = parent_map(effective_children_map)

        render_ids =
          qualifying_ids
          |> expand_with_ancestor_ids(parent_map)
          |> Enum.uniq()

        section_resources = SectionResourceDepot.get_resources_by_ids(section_id, render_ids)
        section_resources_by_id = Map.new(section_resources, &{&1.resource_id, &1})

        log_missing_section_resources(render_ids, section_resources_by_id, section_id)

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
              parent_map,
              scope_filter_by
            )
          )
          |> apply_curriculum_numbering()

        {state, rows, length(qualifying_ids)}
    end
  end

  defp scope_data(snapshot, required, section_id) do
    scope = snapshot.scope
    scope_resources = Map.get(required, :oracle_instructor_scope_resources, %{})

    %{
      selector: scope_selector(scope),
      label: scope_label(scope, section_id),
      course_title: Map.get(scope_resources, :course_title),
      items: Map.get(scope_resources, :items, [])
    }
  end

  defp scope_selector(%{container_type: :container, container_id: container_id}),
    do: "container:#{container_id}"

  defp scope_selector(_scope), do: "course"

  defp scope_label(%{container_type: :course}, _section_id), do: "Entire Course"

  defp scope_label(%{container_type: :container, container_id: container_id}, section_id) do
    case SectionResourceDepot.get_section_resource(section_id, container_id) do
      nil -> "Selected Scope"
      resource -> resource.title
    end
  end

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
    objective_resource_ids = MapSet.new(Enum.map(section_resources, & &1.resource_id))

    revision_children_by_resource_id =
      section_resources
      |> Enum.map(& &1.revision_id)
      |> revision_children_by_resource_id(objective_resource_ids)

    Enum.into(section_resources, %{}, fn section_resource ->
      children =
        case section_resource.children || [] do
          [] -> Map.get(revision_children_by_resource_id, section_resource.resource_id, [])
          child_ids -> child_ids
        end

      {section_resource.resource_id, children}
    end)
  end

  defp revision_children_by_resource_id([], _objective_resource_ids), do: %{}

  defp revision_children_by_resource_id(revision_ids, objective_resource_ids) do
    from(r in Revision,
      where: r.id in ^revision_ids,
      select: {r.resource_id, r.children}
    )
    |> Repo.all()
    |> Enum.into(%{}, fn {resource_id, children} ->
      effective_children =
        children
        |> List.wrap()
        |> Enum.filter(&MapSet.member?(objective_resource_ids, &1))

      {resource_id, effective_children}
    end)
  end

  defp expand_with_ancestor_ids(ids, parent_map) do
    Enum.reduce(ids, ids, fn objective_id, acc ->
      collect_ancestor_ids(objective_id, parent_map, acc)
    end)
  end

  defp collect_ancestor_ids(objective_id, parent_map, acc) do
    case Map.get(parent_map, objective_id) do
      nil ->
        acc

      parent_id ->
        if parent_id in acc do
          acc
        else
          collect_ancestor_ids(parent_id, parent_map, [parent_id | acc])
        end
    end
  end

  defp build_row(
         section_resource,
         section_resources_by_id,
         all_objective_resources_by_id,
         effective_children_map,
         objective_rows_by_id,
         parent_map,
         scope_filter_by
       ) do
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

    %{
      objective_id: section_resource.resource_id,
      parent_objective_id: parent_id,
      parent_title: parent_title,
      title: objective_title(section_resource, objective_row),
      row_type: if(is_nil(parent_id), do: :objective, else: :subobjective),
      numbering: nil,
      numbering_index: section_resource.numbering_index,
      numbering_level: section_resource.numbering_level,
      proficiency_label: proficiency_label(objective_row),
      proficiency_distribution: proficiency_distribution(objective_row),
      has_children: child_ids != [],
      children:
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
            parent_map,
            scope_filter_by
          )
        ),
      navigation:
        navigation_for(
          section_resource.resource_id,
          parent_id,
          if(is_nil(parent_id), do: :objective, else: :subobjective),
          scope_filter_by
        )
    }
  end

  defp navigation_for(objective_id, nil, :objective, scope_filter_by) do
    navigation_for_scope(scope_filter_by)
    |> Map.merge(%{
      selected_card_value: :low_proficiency_outcomes,
      objective_id: objective_id
    })
  end

  defp navigation_for(objective_id, parent_objective_id, :subobjective, scope_filter_by) do
    navigation_for_scope(scope_filter_by)
    |> Map.merge(%{
      selected_card_value: :low_proficiency_skills,
      objective_id: parent_objective_id || objective_id,
      subobjective_id: objective_id
    })
  end

  defp navigation_for_scope(nil), do: %{navigation_source: "challenging_objectives_tile"}

  defp navigation_for_scope(filter_by),
    do: %{filter_by: filter_by, navigation_source: "challenging_objectives_tile"}

  defp apply_curriculum_numbering(rows), do: apply_curriculum_numbering(rows, nil)

  defp apply_curriculum_numbering(rows, prefix) do
    rows
    |> Enum.with_index(1)
    |> Enum.map(fn {row, index} ->
      numbering =
        case prefix do
          nil -> Integer.to_string(index)
          prefix -> "#{prefix}.#{index}"
        end

      row
      |> Map.put(:numbering, numbering)
      |> Map.update!(:children, &apply_curriculum_numbering(&1, numbering))
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
      Enum.any?(
        @meaningful_proficiency_levels,
        &(Map.get(row.proficiency_distribution, &1, 0) > 0)
      )
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

  defp log_missing_section_resources(qualifying_ids, section_resources_by_id, section_id) do
    missing_ids = Enum.reject(qualifying_ids, &Map.has_key?(section_resources_by_id, &1))

    if missing_ids != [] do
      Logger.warning(
        "challenging_objectives_projection.missing_section_resources section_id=#{section_id} missing_ids=#{inspect(missing_ids)}"
      )
    end
  end
end
