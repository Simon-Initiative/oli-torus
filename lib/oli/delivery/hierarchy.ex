defmodule Oli.Delivery.Hierarchy do
  @moduledoc """
  A module for hierarchy and HierarchyNode operations and utilities
  A delivery hierarchy is the main structure in which a course curriculum is organized
  to be delivered. It is mainly persisted through section resource records. A hierarchy is
  also a generic in-memory representation of a curriculum which can be passed into
  delivery-centric functions from an authoring context, in which case the hierarchy could
  be ephemeral and section_resources are empty (e.g. course preview)
  See also HierarchyNode for more details
  """
  import Oli.Utils

  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Resources.Numbering
  alias Oli.Publishing.PublishedResource
  alias Oli.Resources.ResourceType

  @doc """
  From a constructed hierarchy root node, or a collection of hierarchy nodes, return
  an ordered flat list of the nodes of only the pages in the hierarchy.
  """
  def flatten_pages(nodes) when is_list(nodes) do
    Enum.reduce(nodes, [], &flatten_pages(&1, &2))
  end

  def flatten_pages(%HierarchyNode{} = node), do: flatten_pages(node, []) |> Enum.reverse()

  defp flatten_pages(%HierarchyNode{} = node, all) do
    if ResourceType.is_page(node.revision) do
      [node | all]
    else
      Enum.reduce(node.children, all, &flatten_pages(&1, &2))
    end
  end

  @doc """
  From a constructed hierarchy root node return an ordered flat list of all the nodes
  in the hierarchy. Containers appear before their contents
  """
  def flatten_hierarchy(%HierarchyNode{} = node),
    do: flatten_hierarchy(node, []) |> Enum.reverse()

  defp flatten_hierarchy(%HierarchyNode{} = node, all) do
    all = [node | all]

    Enum.reduce(node.children, all, &flatten_hierarchy(&1, &2))
  end

  def create_hierarchy(revision, published_resources_by_resource_id) do
    numbering_tracker = Numbering.init_numbering_tracker()
    level = 0

    create_hierarchy(revision, published_resources_by_resource_id, level, numbering_tracker)
  end

  defp create_hierarchy(revision, published_resources_by_resource_id, level, numbering_tracker) do
    {index, numbering_tracker} = Numbering.next_index(numbering_tracker, level, revision)

    children =
      Enum.map(revision.children, fn child_id ->
        %PublishedResource{revision: child_revision} =
          published_resources_by_resource_id[child_id]

        create_hierarchy(
          child_revision,
          published_resources_by_resource_id,
          level + 1,
          numbering_tracker
        )
      end)

    %PublishedResource{publication: pub} =
      published_resources_by_resource_id[revision.resource_id]

    %HierarchyNode{
      uuid: uuid(),
      numbering: %Numbering{
        index: index,
        level: level
      },
      revision: revision,
      resource_id: revision.resource_id,
      project_id: pub.project_id,
      children: children
    }
  end

  @doc """
  Crawls the hierarchy and removes any nodes with duplicate resource_ids.
  The first node encountered with a resource_id will be left in place,
  any subsequent duplicates will be removed from the hierarchy
  """
  def purge_duplicate_resources(%HierarchyNode{} = hierarchy) do
    purge_duplicate_resources(hierarchy, %{})
    |> then(fn {hierarchy, _} -> hierarchy end)
  end

  def purge_duplicate_resources(
        %HierarchyNode{resource_id: resource_id, children: children} = node,
        processed_nodes
      ) do
    processed_nodes = Map.put_new(processed_nodes, resource_id, node)

    {children, processed_nodes} =
      Enum.reduce(children, {[], processed_nodes}, fn child, {children, processed_nodes} ->
        # filter out any child which has already been processed or recursively process the child node
        if Map.has_key?(processed_nodes, child.resource_id) do
          # skip child, as it is a duplicate resource
          {children, processed_nodes}
        else
          {child, processed_nodes} = purge_duplicate_resources(child, processed_nodes)
          {[child | children], processed_nodes}
        end
      end)
      |> then(fn {children, processed_nodes} -> {Enum.reverse(children), processed_nodes} end)

    {%HierarchyNode{node | children: children}, processed_nodes}
  end

  def find_in_hierarchy(
        %HierarchyNode{uuid: uuid, children: children} = node,
        uuid_to_find
      )
      when is_binary(uuid_to_find) do
    if uuid == uuid_to_find do
      node
    else
      Enum.reduce(children, nil, fn child, acc ->
        if acc == nil, do: find_in_hierarchy(child, uuid_to_find), else: acc
      end)
    end
  end

  def find_in_hierarchy(
        %HierarchyNode{children: children} = node,
        find_by
      )
      when is_function(find_by) do
    if find_by.(node) do
      node
    else
      Enum.reduce(children, nil, fn child, acc ->
        if acc == nil, do: find_in_hierarchy(child, find_by), else: acc
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
    if hierarchy.uuid == node.uuid do
      node
    else
      %HierarchyNode{
        hierarchy
        | children:
            Enum.map(hierarchy.children, fn child -> find_and_update_node(child, node) end)
      }
    end
  end

  def find_and_remove_node(hierarchy, uuid) do
    if uuid in Enum.map(hierarchy.children, & &1.uuid) do
      %HierarchyNode{
        hierarchy
        | children: Enum.filter(hierarchy.children, fn child -> child.uuid != uuid end)
      }
    else
      %HierarchyNode{
        hierarchy
        | children:
            Enum.map(hierarchy.children, fn child -> find_and_remove_node(child, uuid) end)
      }
    end
  end

  def move_node(hierarchy, node, destination_uuid) do
    hierarchy = find_and_remove_node(hierarchy, node.uuid)
    destination = find_in_hierarchy(hierarchy, destination_uuid)

    updated_container = %HierarchyNode{destination | children: [node | destination.children]}

    find_and_update_node(hierarchy, updated_container)
  end

  def add_materials_to_hierarchy(
        hierarchy,
        active,
        selection,
        published_resources_by_resource_id_by_pub
      ) do
    nodes =
      selection
      |> Enum.map(fn {publication_id, resource_id} ->
        revision =
          published_resources_by_resource_id_by_pub
          |> Map.get(publication_id)
          |> Map.get(resource_id)
          |> Map.get(:revision)

        create_hierarchy(revision, published_resources_by_resource_id_by_pub[publication_id])
      end)

    find_and_update_node(hierarchy, %HierarchyNode{active | children: active.children ++ nodes})
    |> Numbering.renumber_hierarchy()
    |> then(fn {updated_hierarchy, _numberings} -> updated_hierarchy end)
  end

  @doc """
  Given a course section hierarchy, this function builds a "navigation link map" for a course section that is
  used during delivery to efficiently render the "Previous" and "Next" page links.

  This function produces a map of resource ids (as string keys) to inner maps containing previous and next
  resource ids references (again as strings) as well as the page title and slug. An example navigation link map is:

  ```
  %{
    "1" => %{
      "prev" => nil,
      "next" => "2",
      "title" => "Introduction to Biology",
      "slug" => "intro_bio"
    },
    "2" => %{
      "prev" => "1",
      "next" => "3",
      "title" => "Photosynthesis",
      "slug" => "photosyn_2",
    },
    "3" => %{
      "prev" => "2",
      "next" => nil,
      "title" => "Final Exam",
      "slug" => "final_exam"
    }
  }
  ```

  The above construct is designed to allow a lightweight, constant time determination
  (and then rendering) of Previous and Next links.  Given a resource id of the current
  page, at most three map lookups are required to gather all the information required to
  render links.  It is expected that this map is already in memory, retrieved from the
  section record itself, which overall then greatly improves the performance of
  determining prev and next links.
  """
  def build_navigation_link_map(%HierarchyNode{} = root) do
    {map, _} =
      flatten(root)
      |> Enum.reduce({%{}, nil}, fn node, {map, previous} ->
        this_id = Integer.to_string(node.revision.resource_id)

        this_entry = %{
          "slug" => node.revision.slug,
          "title" => node.revision.title,
          "prev" =>
            case previous do
              nil -> nil
              _ -> previous
            end,
          "next" => nil
        }

        map =
          case previous do
            nil ->
              map

            id ->
              previous_entry = Map.get(map, id)
              updated = Map.merge(previous_entry, %{"next" => this_id})
              Map.put(map, id, updated)
          end

        {Map.put(map, this_id, this_entry), this_id}
      end)

    map
  end

  @doc """
  Given a hierarchy node, this function "flattens" all nodes below into a list, in the order that
  a student would encounter the resources working linearly through a course.
  As an example, consider the following hierarchy:
  --Unit 1
  ----Module 1
  ------Page A
  ------Page B
  --Unit 2
  ----Moudule 2
  ------Page C
  The above would be flattened to:
  Unit 1
  Module 1
  Page A
  Page B
  Unit 2
  Module 2
  Page C
  """
  def flatten(%HierarchyNode{} = root) do
    flatten_helper(root, [], [])
    |> Enum.reverse()
  end

  defp flatten_helper(%HierarchyNode{children: children}, flattened_nodes, current_ancestors) do
    Enum.reduce(children, flattened_nodes, fn node, acc ->
      node = %{node | ancestors: current_ancestors}

      case ResourceType.get_type_by_id(node.revision.resource_type_id) do
        "container" -> flatten_helper(node, [node | acc], current_ancestors ++ [node])
        _ -> [node | acc]
      end
    end)
  end

  @doc """
  Builds a map that contains a list of gated ancestor resource_ids for each node. The list will
  contain the resource_id of the node itself, if that resource is gated.
  The keys of the map will be returned as strings, but the list of resource_ids themselves
  will be integers. This is done this way for consistency because when this map gets
  persisted to a the Postgres JSON datatype, these keys will be stored to strings.
  Takes 2 parameters. First is the root of the hierarchy. Second is a gated_resource_id_map
  which is a map containing the resource_ids of gated resources as keys (the value is ignored)
  For example, consider the following hierarchy:
  --Unit 1 (gated: true, resource_id: 1)
  ----Module 1 (gated: true, resource_id: 2)
  ------Page A (gated: true, resource_id: 3)
  ------Page B (gated: false, resource_id: 4)
  --Unit 2 (gated: false, resource_id: 5)
  ----Moudule 2 (gated: false, resource_id: 6)
  ------Page C (gated: true, resource_id: 7)
  The following ancestry map will be returned:
  %{
    "1" => [1],
    "2" => [2, 1],
    "3" => [3, 2 ,1],
    "4" => [2, 1],
    "7" => [7]
  }
  """
  def gated_ancestry_map(%HierarchyNode{} = root, %{} = gated_resource_id_map) do
    gated_ancestry_map(root, %{}, [], gated_resource_id_map)
  end

  defp gated_ancestry_map(
         %HierarchyNode{resource_id: resource_id, children: children},
         index_map,
         gated_ancestors,
         gated_resource_id_map
       ) do
    # if this node is gated, then we add it to the list of gated ancestors
    gated_ancestors =
      if Map.has_key?(gated_resource_id_map, resource_id) do
        [resource_id | gated_ancestors]
      else
        gated_ancestors
      end

    # if any ancestors are gated (including the current node), then add it to the index
    index_map =
      if Enum.empty?(gated_ancestors) == false do
        Map.put(index_map, ensure_string(resource_id), gated_ancestors)
      else
        index_map
      end

    Enum.reduce(children, index_map, fn node, acc ->
      gated_ancestry_map(node, acc, gated_ancestors, gated_resource_id_map)
    end)
  end

  defp ensure_string(maybe_str) when is_binary(maybe_str), do: maybe_str
  defp ensure_string(maybe_str) when is_integer(maybe_str), do: Integer.to_string(maybe_str)

  @doc """
  Debugging utility to inspect a hierarchy without all the noise. Choose which keys
  to drop in the HierarchyNodes using the drop_keys option.
  """
  def inspect(%HierarchyNode{} = hierarchy, opts \\ []) do
    label = Keyword.get(opts, :label)
    drop_keys = Keyword.get(opts, :drop_keys, [:revision, :section_resource])

    drop_r(hierarchy, drop_keys)
    # credo:disable-for-next-line Credo.Check.Warning.IoInspect
    |> IO.inspect(label: label)

    hierarchy
  end

  defp drop_r(%HierarchyNode{children: children} = node, drop_keys) do
    %HierarchyNode{node | children: Enum.map(children, &drop_r(&1, drop_keys))}
    |> Map.drop([:__struct__ | drop_keys])
  end
end
