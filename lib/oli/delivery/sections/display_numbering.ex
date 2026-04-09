defmodule Oli.Delivery.Sections.DisplayNumbering do
  @moduledoc """
  Computes display-only numbering overlays for delivery hierarchies.

  Canonical numbering remains untouched. The returned hierarchy is decorated with
  a `display_numbering` field that can be consumed by rendering helpers when
  container numbering should skip top-level units listed in
  `section.unnumbered_unit_ids`.
  """

  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Delivery.Sections.Section
  alias Oli.Resources.Numbering
  alias Oli.Resources.ResourceType

  @container_type "container"

  def decorate_hierarchy(%Section{} = section, hierarchy) do
    case section.unnumbered_unit_ids || [] do
      [] ->
        hierarchy

      unnumbered_unit_ids ->
        unnumbered_unit_ids = MapSet.new(unnumbered_unit_ids)
        {hierarchy, _counters} = do_decorate(hierarchy, %{}, unnumbered_unit_ids, false)
        hierarchy
    end
  end

  defp do_decorate(%HierarchyNode{} = node, counters, unnumbered_unit_ids, in_unnumbered_subtree) do
    container? = container?(node)
    level = node.numbering.level

    subtree_unnumbered? =
      in_unnumbered_subtree or
        (container? and level == 1 and MapSet.member?(unnumbered_unit_ids, node.resource_id))

    {display_numbering, counters} =
      display_numbering(node.numbering, container?, level, subtree_unnumbered?, counters)

    {children, counters} =
      Enum.map_reduce(node.children, counters, fn child, counters ->
        do_decorate(child, counters, unnumbered_unit_ids, subtree_unnumbered?)
      end)

    {%{node | display_numbering: display_numbering, children: children}, counters}
  end

  defp do_decorate(
         %{"numbering" => numbering} = node,
         counters,
         unnumbered_unit_ids,
         in_unnumbered_subtree
       ) do
    container? = container?(node)
    level = parse_index(numbering["level"])

    subtree_unnumbered? =
      in_unnumbered_subtree or
        (container? and level == 1 and MapSet.member?(unnumbered_unit_ids, node["resource_id"]))

    {display_numbering, counters} =
      display_numbering(numbering, container?, level, subtree_unnumbered?, counters)

    {children, counters} =
      Enum.map_reduce(node["children"] || [], counters, fn child, counters ->
        do_decorate(child, counters, unnumbered_unit_ids, subtree_unnumbered?)
      end)

    {Map.put(node, "display_numbering", display_numbering) |> Map.put("children", children),
     counters}
  end

  defp display_numbering(numbering, false, _level, _subtree_unnumbered?, counters),
    do: {numbering, counters}

  defp display_numbering(numbering, true, 0, _subtree_unnumbered?, counters),
    do: {numbering, counters}

  defp display_numbering(_numbering, true, _level, true, counters),
    do: {nil, counters}

  defp display_numbering(%Numbering{} = numbering, true, level, false, counters) do
    next_index = Map.get(counters, level, 1)
    {%{numbering | index: next_index}, Map.put(counters, level, next_index + 1)}
  end

  defp display_numbering(%{} = numbering, true, level, false, counters) do
    next_index = Map.get(counters, level, 1)
    {Map.put(numbering, "index", next_index), Map.put(counters, level, next_index + 1)}
  end

  defp container?(%HierarchyNode{revision: %{resource_type_id: resource_type_id}}) do
    ResourceType.get_type_by_id(resource_type_id) == @container_type
  end

  defp container?(%{"resource_type_id" => resource_type_id}) do
    ResourceType.get_type_by_id(resource_type_id) == @container_type
  end

  defp parse_index(value) when is_integer(value), do: value
  defp parse_index(value) when is_binary(value), do: String.to_integer(value)
end
