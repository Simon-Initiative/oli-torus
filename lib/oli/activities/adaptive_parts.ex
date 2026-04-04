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

  def scorable_part_type?(type) when is_binary(type),
    do: MapSet.member?(@scorable_part_types, type)

  def scorable_part_type?(_), do: false

  def scorable_part?(part) when is_map(part), do: scorable_part_type?(Map.get(part, "type"))
  def scorable_part?(_), do: false

  def authored_parts_by_id(content) when is_map(content) do
    content
    |> get_in(["authoring", "parts"])
    |> Kernel.||([])
    |> Enum.reduce(%{}, fn part, acc ->
      Map.put(acc, Map.get(part, "id"), part)
    end)
  end

  def authored_parts_by_id(_), do: %{}

  def part_definition(content, part_id) when is_map(content) and is_binary(part_id) do
    authored_parts_by_id = authored_parts_by_id(content)

    case Enum.find(Map.get(content, "partsLayout", []), &(Map.get(&1, "id") == part_id)) do
      nil -> Map.get(authored_parts_by_id, part_id)
      part -> Map.merge(Map.get(authored_parts_by_id, part_id, %{}), part)
    end
  end

  def part_definition(_, _), do: nil

  def scorable_part_definitions(content) when is_map(content) do
    authored_parts_by_id = authored_parts_by_id(content)

    content
    |> Map.get("partsLayout", [])
    |> Enum.map(fn part ->
      Map.merge(Map.get(authored_parts_by_id, Map.get(part, "id"), %{}), part)
    end)
    |> Enum.filter(&scorable_part?/1)
  end

  def scorable_part_definitions(_), do: []

  def scorable_part_ids(content) do
    content
    |> scorable_part_definitions()
    |> Enum.map(&Map.get(&1, "id"))
    |> MapSet.new()
  end

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
    case Map.get(part, "gradingApproach") do
      "manual" -> :manual
      _ -> :automatic
    end
  end
end
