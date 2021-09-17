defmodule Oli.Publishing.HierarchyNode do
  alias Oli.Publishing.HierarchyNode

  defstruct numbering: nil,
            children: [],
            resource_id: nil,
            revision: nil,
            section_resource: nil

  @doc """
  From a constructed hierarchy root node, or a collection of hierarchy nodes, return
  an ordered flat list of the nodes of only the pages in the hierarchy.
  """
  def flatten_pages(nodes) when is_list(nodes) do
    Enum.reduce(nodes, [], &flatten_pages(&1, &2))
  end

  def flatten_pages(%HierarchyNode{} = node), do: flatten_pages(node, []) |> Enum.reverse()

  defp flatten_pages(%HierarchyNode{} = node, all) do
    if node.revision.resource_type_id == Oli.Resources.ResourceType.get_id_by_type("page") do
      [node | all]
    else
      Enum.reduce(node.children, all, &flatten_pages(&1, &2))
    end
  end

  def find_in_hierarchy(
        %HierarchyNode{section_resource: sr, children: children} = node,
        section_resource_slug
      ) do
    if sr.slug == section_resource_slug do
      node
    else
      Enum.reduce(children, nil, fn child, acc ->
        if acc == nil, do: find_in_hierarchy(child, section_resource_slug), else: acc
      end)
    end
  end

  def reorder_children(
        children,
        node,
        source_index,
        index
      ) do
    insert_index =
      if source_index < index do
        index - 1
      else
        index
      end

    children =
      Enum.filter(children, fn %HierarchyNode{revision: r} -> r.id !== node.revision.id end)
      |> List.insert_at(insert_index, node)

    children
  end

  def find_and_update_node(hierarchy, node) do
    if hierarchy.section_resource.id == node.section_resource.id do
      node
    else
      %HierarchyNode{
        hierarchy
        | children:
            Enum.map(hierarchy.children, fn child -> find_and_update_node(child, node) end)
      }
    end
  end

  @doc """
  Debugging utility to inspect a hierarchy without all the noise. Choose which keys
  to drop in the HierarchyNodes using the drop_keys option.
  """
  def inspect(%HierarchyNode{} = hierarchy, opts \\ []) do
    label = Keyword.get(opts, :label)
    drop_keys = Keyword.get(opts, :drop_keys, [:revision, :section_resource])

    drop_r(hierarchy, drop_keys)
    |> IO.inspect(label: label)
  end

  defp drop_r(%HierarchyNode{children: children} = node, drop_keys) do
    %HierarchyNode{node | children: Enum.map(children, fn n -> drop_r(n, drop_keys) end)}
    |> Map.drop([:__struct__ | drop_keys])
  end
end
