defmodule Oli.Publishing.HierarchyNode do
  @moduledoc """
  HierarchyNode is a generic in-memory representation of a node within a hierarchy. This struct
  is shared accross authoring and delivery and allows gerneralized components to work in both.

  A hierarchy is a single root node which contains children. The children in a node are intended
  to be fully instantiated structs (as opposed to just identifiers. However during the process of
  instantiateing the hierarchy, children may temporarily be set as an identifer until the full
  hierarchy is instantiated).

  Notice that the hierarhcy node also has a "slug" value. This value is used to uniquely identify
  the node within a set of nodes and therefore can be set to the revision's slug or section_resource's
  slug depending on which is more applicable. For example, a section's hierarchy could theoretically
  contain multiple nodes that have the same revision, and therefore using the section reource slug
  is more appropriate in the delivery context. However, since section resources do not exist in the
  authoring context, using the revision slug will be more appropriate. The actual values used are not
  necessarily important other than to uniquely identify the node in the hierarchy.
  """
  alias Oli.Publishing.HierarchyNode

  defstruct slug: nil,
            numbering: nil,
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
        %HierarchyNode{slug: slug, children: children} = node,
        slug_to_find
      ) do
    if slug == slug_to_find do
      node
    else
      Enum.reduce(children, nil, fn child, acc ->
        if acc == nil, do: find_in_hierarchy(child, slug_to_find), else: acc
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

  def find_and_remove_node(hierarchy, node) do
    if node.slug in Enum.map(hierarchy.children, & &1.slug) do
      %HierarchyNode{
        hierarchy
        | children: Enum.filter(hierarchy.children, fn child -> child.slug != node.slug end)
      }
    else
      %HierarchyNode{
        hierarchy
        | children:
            Enum.map(hierarchy.children, fn child -> find_and_remove_node(child, node) end)
      }
    end
  end

  def move_node(hierarchy, node, destination_slug) do
    hierarchy = find_and_remove_node(hierarchy, node)
    destination = find_in_hierarchy(hierarchy, destination_slug)

    updated_container = %HierarchyNode{destination | children: [node | destination.children]}

    find_and_update_node(hierarchy, updated_container)
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

    hierarchy
  end

  defp drop_r(%HierarchyNode{children: children} = node, drop_keys) do
    %HierarchyNode{node | children: Enum.map(children, fn n -> drop_r(n, drop_keys) end)}
    |> Map.drop([:__struct__ | drop_keys])
  end
end
