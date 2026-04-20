defmodule Oli.Activities.AdaptiveParts do
  @moduledoc false

  @scorable_part_types MapSet.new([
                         "janus-mcq",
                         "janus-input-text",
                         "janus-input-number",
                         "janus-dropdown",
                         "janus-slider",
                         "janus-multi-line-text",
                         "janus-hub-spoke",
                         "janus-text-slider",
                         "janus-fill-blanks"
                       ])

  def scorable_part_types, do: @scorable_part_types

  def scorable_part_type?(type) when is_binary(type),
    do: MapSet.member?(@scorable_part_types, type)

  def scorable_part_type?(_), do: false

  def scorable_part?(part) when is_map(part), do: scorable_part_type?(Map.get(part, "type"))
  def scorable_part?(_), do: false

  def tracked_part?(content, part_id) when is_map(content) and is_binary(part_id) do
    MapSet.member?(tracked_part_ids(content), part_id)
  end

  def tracked_part?(content, %{"id" => part_id}) when is_map(content) and is_binary(part_id),
    do: tracked_part?(content, part_id)

  def tracked_part?(_, _), do: false

  def rule_scored_part?(content, part_id) when is_map(content) and is_binary(part_id) do
    MapSet.member?(rule_scored_part_ids(content), part_id)
  end

  def rule_scored_part?(content, %{"id" => part_id}) when is_map(content) and is_binary(part_id),
    do: rule_scored_part?(content, part_id)

  def rule_scored_part?(_, _), do: false

  def authored_parts_by_id(content) when is_map(content) do
    content
    |> get_in(["authoring", "parts"])
    |> Kernel.||([])
    |> Enum.reduce(%{}, fn part, acc ->
      Map.put(acc, Map.get(part, "id"), part)
    end)
  end

  def authored_parts_by_id(_), do: %{}

  def parts_layout_by_id(content) when is_map(content) do
    content
    |> Map.get("partsLayout", [])
    |> Enum.reduce(%{}, fn part, acc ->
      Map.put(acc, Map.get(part, "id"), part)
    end)
  end

  def parts_layout_by_id(_), do: %{}

  def merged_parts_by_id(content) when is_map(content) do
    Map.merge(authored_parts_by_id(content), parts_layout_by_id(content), fn _part_id,
                                                                             authored,
                                                                             layout ->
      Map.merge(authored, layout)
    end)
  end

  def merged_parts_by_id(_), do: %{}

  def part_definition(content, part_id) when is_map(content) and is_binary(part_id) do
    Map.get(merged_parts_by_id(content), part_id)
  end

  def part_definition(_, _), do: nil

  def scorable_part_definitions(content) when is_map(content) do
    merged_parts = merged_parts_by_id(content)

    content
    |> ordered_part_ids()
    |> Enum.map(&Map.get(merged_parts, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(&scorable_part?/1)
  end

  def scorable_part_definitions(_), do: []

  def scorable_part_ids(content) do
    content
    |> scorable_part_definitions()
    |> Enum.map(&Map.get(&1, "id"))
    |> MapSet.new()
  end

  def rule_scored_part_definitions(content) when is_map(content) do
    merged_parts = merged_parts_by_id(content)
    rule_scored_ids = rule_scored_part_ids(content)

    content
    |> ordered_part_ids()
    |> Enum.filter(&MapSet.member?(rule_scored_ids, &1))
    |> Enum.map(&Map.get(merged_parts, &1))
    |> Enum.reject(&is_nil/1)
  end

  def rule_scored_part_definitions(_), do: []

  def tracked_part_definitions(content) when is_map(content) do
    merged_parts = merged_parts_by_id(content)
    tracked_ids = tracked_part_ids(content)

    content
    |> ordered_part_ids()
    |> Enum.filter(&MapSet.member?(tracked_ids, &1))
    |> Enum.map(&Map.get(merged_parts, &1))
    |> Enum.reject(&is_nil/1)
  end

  def tracked_part_definitions(_), do: []

  def tracked_part_ids(content) do
    MapSet.union(scorable_part_ids(content), rule_scored_part_ids(content))
  end

  def rule_scored_part_ids(content) when is_map(content) do
    merged_parts = merged_parts_by_id(content)

    content
    |> Map.get("authoring", %{})
    |> Map.get("rules", [])
    |> Enum.reduce(MapSet.new(), fn rule, acc ->
      if rule_scoring_relevant?(rule) do
        rule
        |> collect_rule_condition_part_ids()
        |> Enum.reduce(acc, fn part_id, inner_acc ->
          case Map.get(merged_parts, part_id) do
            %{} = part ->
              if scorable_part?(part) do
                inner_acc
              else
                MapSet.put(inner_acc, part_id)
              end

            _ ->
              inner_acc
          end
        end)
      else
        acc
      end
    end)
  end

  def rule_scored_part_ids(_), do: MapSet.new()

  def adaptive_activity?(revision) when is_map(revision) do
    adaptive_activity_type_id() == Map.get(revision, :activity_type_id)
  end

  def adaptive_activity_type_id do
    case Oli.Activities.get_registration_by_slug("oli_adaptive") do
      nil -> nil
      registration -> registration.id
    end
  end

  def grading_approach(part) when is_map(part) do
    custom = Map.get(part, "custom", %{})

    cond do
      Map.get(custom, "requiresManualGrading") == true ->
        :manual

      Map.get(custom, "requireManualGrading") == true ->
        :manual

      Map.get(part, "gradingApproach") == "manual" ->
        :manual

      true ->
        :automatic
    end
  end

  def tracked_part_grading_approach(content, part) when is_map(content) and is_map(part) do
    if rule_scored_part?(content, part) and not scorable_part?(part) do
      :automatic
    else
      grading_approach(part)
    end
  end

  def tracked_part_grading_approach(_content, part), do: grading_approach(part)

  defp ordered_part_ids(content) when is_map(content) do
    layout_ids =
      content
      |> Map.get("partsLayout", [])
      |> Enum.map(&Map.get(&1, "id"))
      |> Enum.reject(&is_nil/1)

    authored_ids =
      content
      |> get_in(["authoring", "parts"])
      |> Kernel.||([])
      |> Enum.map(&Map.get(&1, "id"))
      |> Enum.reject(&is_nil/1)

    Enum.uniq(layout_ids ++ authored_ids)
  end

  defp ordered_part_ids(_), do: []

  defp rule_scoring_relevant?(rule) when is_map(rule) do
    Map.get(rule, "disabled") != true and Map.get(rule, :disabled) != true
  end

  defp rule_scoring_relevant?(_), do: false

  defp collect_rule_condition_part_ids(rule) when is_map(rule) do
    rule
    |> Map.get("conditions", Map.get(rule, :conditions, %{}))
    |> collect_stage_part_ids_from_term()
    |> Enum.uniq()
  end

  defp collect_rule_condition_part_ids(_), do: []

  defp collect_stage_part_ids_from_term(term) when is_map(term) do
    Enum.flat_map(term, fn {_key, value} -> collect_stage_part_ids_from_term(value) end)
  end

  defp collect_stage_part_ids_from_term(term) when is_list(term) do
    Enum.flat_map(term, &collect_stage_part_ids_from_term/1)
  end

  defp collect_stage_part_ids_from_term(term) when is_binary(term) do
    Regex.scan(~r/stage\.([^.]+)\./, term, capture: :all_but_first)
    |> Enum.map(fn [part_id] -> part_id end)
  end

  defp collect_stage_part_ids_from_term(_), do: []
end
