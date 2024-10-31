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
  import Ecto.Query, warn: false, only: [from: 2]

  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Resources.Numbering
  alias Oli.Publishing.{DeliveryResolver, PublishedResource}
  alias Oli.Resources.ResourceType
  alias Oli.Branding.CustomLabels
  alias Oli.Authoring.Course.Project
  alias Oli.Repo

  @doc """
  This method should be called after any hierarchy-changing operation
  in this module is used to ensure that numberings remain up to date. Because a lot of the operations
  in this module are chainable, it is up to the caller to ensure numberings are up-to-date
  by running this function after all hierarchy mutating operations are complete.
  """
  def finalize(hierarchy) do
    hierarchy
    |> Numbering.renumber_hierarchy()
    |> then(fn {updated_hierarchy, _numberings} -> updated_hierarchy end)
    |> mark_finalized()
  end

  defp mark_unfinalized(%HierarchyNode{} = node) do
    %HierarchyNode{node | finalized: false}
  end

  defp mark_finalized(%HierarchyNode{} = node) do
    %HierarchyNode{node | finalized: true, children: Enum.map(node.children, &mark_finalized/1)}
  end

  @doc """
  Returns true if a node and all it's descendent's are finalized
  """
  def finalized?(%HierarchyNode{} = node) do
    node.finalized and Enum.all?(node.children, &finalized?/1)
  end

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

  @doc """
  Constructs an in-memory hierarchy from a given root revision using the provided
  published_resources_by_resource_id map
  """
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

    pub = Repo.preload(pub, :project)

    labels =
      case pub.project.customizations do
        nil -> CustomLabels.default_map()
        l -> Map.from_struct(l)
      end

    %HierarchyNode{
      uuid: uuid(),
      numbering: %Numbering{
        index: index,
        level: level,
        labels: labels
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
    |> mark_unfinalized()
  end

  defp purge_duplicate_resources(
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

  @doc """
  Finds a node in the hierarchy with the given uuid or function `fn node -> true`
  """
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

  @doc """
  Finds the parent node of the matching node in the hierarchy with the given uuid
  or function `fn node -> true`.

  Returns the first parent that contains the matching node.
  """
  def find_parent_in_hierarchy(
        node,
        uuid_or_find_by_fn,
        parent \\ nil
      )

  def find_parent_in_hierarchy(
        %HierarchyNode{uuid: uuid, children: children} = node,
        uuid_to_find,
        parent
      )
      when is_binary(uuid_to_find) do
    if uuid == uuid_to_find do
      parent
    else
      Enum.reduce(children, nil, fn child, acc ->
        if acc == nil, do: find_parent_in_hierarchy(child, uuid_to_find, node), else: acc
      end)
    end
  end

  def find_parent_in_hierarchy(
        %HierarchyNode{children: children} = node,
        find_by,
        parent
      )
      when is_function(find_by) do
    if find_by.(node) do
      parent
    else
      Enum.reduce(children, nil, fn child, acc ->
        if acc == nil, do: find_parent_in_hierarchy(child, find_by, node), else: acc
      end)
    end
  end

  def find_parent_in_hierarchy(
        %{"uuid" => uuid, "children" => children} = node,
        uuid_to_find,
        parent
      )
      when is_binary(uuid_to_find) do
    if uuid == uuid_to_find do
      parent
    else
      Enum.reduce(children, nil, fn child, acc ->
        if acc == nil, do: find_parent_in_hierarchy(child, uuid_to_find, node), else: acc
      end)
    end
  end

  def find_parent_in_hierarchy(
        %{"children" => children} = node,
        find_by,
        parent
      )
      when is_function(find_by) do
    if find_by.(node) do
      parent
    else
      Enum.reduce(children, nil, fn child, acc ->
        if acc == nil, do: find_parent_in_hierarchy(child, find_by, node), else: acc
      end)
    end
  end

  @doc """
  Finds the nearest ancestor module in a given hierarchy that matches the specified container resource type.

  ## Parameters:
  - `hierarchy` : The complete hierarchy of the course.
  - `resource_id` : The resource ID for which to find the ancestor.
  - `container_resource_type_id` : The resource type ID that the ancestor must match.

  ## Returns:
  - Returns the matching ancestor module as a map if found, otherwise `nil`.
  """
  @spec find_module_ancestor(map(), integer() | nil, integer()) :: map() | nil
  def find_module_ancestor(_, nil, _), do: nil

  def find_module_ancestor(hierarchy, resource_id, container_resource_type_id) do
    case Oli.Delivery.Hierarchy.find_parent_in_hierarchy(
           hierarchy,
           &(&1["resource_id"] == resource_id)
         ) do
      %{"resource_type_id" => ^container_resource_type_id, "numbering" => %{"level" => 2}} =
          module ->
        module

      parent ->
        find_module_ancestor(hierarchy, parent["resource_id"], container_resource_type_id)
    end
  end

  @doc """
  Generates the full hierarchy of a given section, including all the attributrs required for student delivery views.
  """
  def full_hierarchy(section, section_resources) when is_list(section_resources) do
    {hierarchy_nodes, root_hierarchy_node} = hierarchy_nodes_by_sr_id(section, section_resources)

    hierarchy_node_with_children(root_hierarchy_node, hierarchy_nodes)
  end

  def full_hierarchy(section) do
    {hierarchy_nodes, root_hierarchy_node} = hierarchy_nodes_by_sr_id(section)

    hierarchy_node_with_children(root_hierarchy_node, hierarchy_nodes)
  end

  # Returns a map of resource ids to hierarchy nodes and the root hierarchy node
  defp hierarchy_nodes_by_sr_id(section) do
    page_id = Oli.Resources.ResourceType.get_id_by_type("page")
    container_id = Oli.Resources.ResourceType.get_id_by_type("container")

    labels =
      case section.customizations do
        nil -> Oli.Branding.CustomLabels.default_map()
        l -> Map.from_struct(l)
      end

    hierarchy_nodes_query(section.slug, page_id, container_id)
    |> Oli.Repo.all()
    |> Enum.map(&add_uuid_and_labels(&1, labels))
    |> Enum.reduce({%{}, nil}, &add_nodes_and_root/2)
  end

  defp hierarchy_nodes_by_sr_id(section, section_resources) do
    labels =
      case section.customizations do
        nil -> Oli.Branding.CustomLabels.default_map()
        l -> Map.from_struct(l)
      end

    hierarchy_nodes_from_srs(section.root_section_resource_id, section_resources)
    |> Enum.map(&add_uuid_and_labels(&1, labels))
    |> Enum.reduce({%{}, nil}, &add_nodes_and_root/2)
  end

  defp add_uuid_and_labels(node, labels) do
    numbering_with_labels = Map.put(node["numbering"], "labels", labels)
    Map.put(node, "uuid", Oli.Utils.uuid()) |> Map.put("numbering", numbering_with_labels)
  end

  defp add_nodes_and_root(item, {nodes, root}) do
    updated_nodes = Map.put(nodes, item["section_resource"].id, item)
    {updated_nodes, if(item["is_root?"], do: item, else: root)}
  end

  defp hierarchy_nodes_query(section_slug, page_id, container_id) do
    from(
      [s: s, sr: sr, rev: rev, spp: spp] in DeliveryResolver.section_resource_revisions(
        section_slug
      ),
      join: p in Project,
      on: p.id == spp.project_id,
      where: rev.resource_type_id in ^[page_id, container_id] and not sr.hidden,
      select: %{
        "id" => rev.id,
        "numbering" => %{"index" => sr.numbering_index, "level" => sr.numbering_level},
        "children" => sr.children,
        "resource_id" => rev.resource_id,
        "project_id" => sr.project_id,
        "project_slug" => p.slug,
        "title" => rev.title,
        "slug" => rev.slug,
        "graded" => rev.graded,
        "intro_video" => rev.intro_video,
        "poster_image" => rev.poster_image,
        "intro_content" => rev.intro_content,
        "duration_minutes" => rev.duration_minutes,
        "resource_type_id" => rev.resource_type_id,
        "section_resource" => sr,
        "is_root?" =>
          fragment("CASE WHEN ? = ? THEN true ELSE false END", sr.id, s.root_section_resource_id)
      }
    )
  end

  defp hierarchy_nodes_from_srs(root_section_resource_id, section_resources) do
    Enum.map(section_resources, fn sr ->
      %{
        "id" => sr.revision_id,
        "numbering" => %{"index" => sr.numbering_index, "level" => sr.numbering_level},
        "children" => sr.children,
        "resource_id" => sr.resource_id,
        "project_id" => sr.project_id,
        "project_slug" => sr.slug,
        "title" => sr.title,
        "slug" => sr.revision_slug,
        "graded" => sr.graded,
        "intro_video" => sr.intro_video,
        "poster_image" => sr.poster_image,
        "intro_content" => sr.intro_content,
        "duration_minutes" => sr.duration_minutes,
        "resource_type_id" => sr.resource_type_id,
        "section_resource" => sr,
        "is_root?" => sr.id == root_section_resource_id
      }
    end)
  end

  defp hierarchy_node_with_children(%{"children" => children_ids} = node, nodes_by_sr_id) do
    Map.put(node, "children", build_updated_children(children_ids, nodes_by_sr_id))
  end

  defp build_updated_children(children_ids, nodes_by_sr_id) do
    children_ids
    |> Enum.filter(&Map.has_key?(nodes_by_sr_id, &1))
    |> Enum.map(&(Map.get(nodes_by_sr_id, &1) |> hierarchy_node_with_children(nodes_by_sr_id)))
  end

  def reorder_children(
        container_node,
        source_node,
        source_index,
        destination_index
      ) do
    insert_index =
      if source_index < destination_index do
        destination_index - 1
      else
        destination_index
      end

    children =
      Enum.filter(container_node.children, fn %HierarchyNode{revision: r} ->
        r.id !== source_node.revision.id
      end)
      |> List.insert_at(insert_index, source_node)

    %HierarchyNode{container_node | children: children}
    |> mark_unfinalized()
  end

  @doc """
  Finds a node with the same uuid in the given hierarchy and updates it with the given node
  """
  def find_and_update_node(hierarchy, node) do
    find_and_update_node_r(hierarchy, node)
    |> mark_unfinalized()
  end

  defp find_and_update_node_r(hierarchy, node) do
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

  @doc """
  Removes a node specified by it's hierarchy uuid from the given hierarchy
  """
  def find_and_remove_node(hierarchy, uuid) do
    find_and_remove_node_r(hierarchy, uuid)
    |> mark_unfinalized()
  end

  defp find_and_remove_node_r(hierarchy, uuid) do
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

  @doc """
  Toggles the hidden attribute of a node in the hierarchy with the given uuid
  """

  def find_and_toggle_hidden(hierarchy, uuid) do
    find_and_toggle_hidden_r(hierarchy, uuid)
    |> mark_unfinalized()
  end

  defp find_and_toggle_hidden_r(hierarchy, uuid) do
    if hierarchy.uuid == uuid do
      updated_section_resource =
        case hierarchy.section_resource do
          nil -> nil
          sr -> Map.put(sr, :hidden, !sr.hidden)
        end

      %HierarchyNode{
        hierarchy
        | section_resource: updated_section_resource
      }
    else
      %HierarchyNode{
        hierarchy
        | children:
            Enum.map(hierarchy.children, fn child -> find_and_toggle_hidden_r(child, uuid) end)
      }
    end
  end

  @doc """
  Moves a node to a given container given by destination uuid
  """
  def move_node(hierarchy, node, destination_uuid) do
    # remove the node from it's previous container
    hierarchy = find_and_remove_node(hierarchy, node.uuid)

    # add the node to it's destination container
    destination = find_in_hierarchy(hierarchy, destination_uuid)
    updated_container = %HierarchyNode{destination | children: [node | destination.children]}

    find_and_update_node(hierarchy, updated_container)
    |> mark_unfinalized()
  end

  @doc """
  Adds the selected materials to a given hierarchy.

  Selection here is a list of tuples representing {publication_id, resource_id}. The resources
  are added to the hierarchy at the active container by appending to the active container's children.

  published_resources_by_resource_id_by_pub is a required supplementary data structure map containing
  resource_id keys to their published resources.
  """
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
    |> mark_unfinalized()
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
      "slug" => "intro_bio",
      "children" => ["4"]
    },
    "2" => %{
      "prev" => "1",
      "next" => "3",
      "title" => "Photosynthesis",
      "slug" => "photosyn_2",
      "children" => []
    },
    "3" => %{
      "prev" => "2",
      "next" => nil,
      "title" => "Final Exam",
      "slug" => "final_exam"
      "children" => []
    }
  }
  ```

  The above construct is designed to allow a lightweight, constant time determination
  (and then rendering) of Previous and Next links.  Given a resource id of the current
  page, at most three map lookups are required to gather all the information required to
  render links.  It is expected that this map is already in memory, retrieved from the
  section record itself, which overall then greatly improves the performance of
  determining prev and next links.

  This structure also supports container (and specifically, children) rendering via
  the "children" attribute.
  """
  def build_navigation_link_map(%HierarchyNode{} = root) do
    {map, _} =
      flatten(root)
      |> Enum.reduce({%{}, nil}, fn node, {map, previous} ->
        this_id = Integer.to_string(node.revision.resource_id)

        this_entry = %{
          "id" => Integer.to_string(node.revision.resource_id),
          "type" => Oli.Resources.ResourceType.get_type_by_id(node.revision.resource_type_id),
          "index" => Integer.to_string(node.numbering.index),
          "level" => Integer.to_string(node.numbering.level),
          "slug" => node.revision.slug,
          "title" => node.revision.title,
          "prev" =>
            case previous do
              nil -> nil
              _ -> previous
            end,
          "next" => nil,
          "graded" => "#{node.revision.graded}",
          "children" =>
            Enum.map(node.children, fn hn -> Integer.to_string(hn.revision.resource_id) end)
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
    |> Map.put_new(:inspect_revision_title, node.revision.title)
    |> Map.put_new(:inspect_revision_slug, node.revision.slug)
  end

  @doc """
    Builds a map of resource_id to unique contained scheduling types for all containers in the hierarchy.

    For example, given this hierarchy:

    Root Container (resource_id = 1):
      |_ Page 1 (resource_id = 2, scheduling_type = :inclass_activity)
      |_ Unit 1 (resource_id = 3):
        |_ Page 2 (resource_id = 4, scheduling_type = :due_by)
        |_ Page 3 (resource_id = 5, scheduling_type = :read_by)
      |_ Unit 2 (resource_id = 6):
        |_ Module 1 (resource_id = 7):
          |_ Page 4 (resource_id = 8, scheduling_type = :read_by)
          |_ Page 5 (resource_id = 9, scheduling_type = :read_by)
          |_ Section 1 (resource_id = 10):
            |_ Page 6 (resource_id = 11, scheduling_type = :due_by)
            |_ Page 7 (resource_id = 12, scheduling_type = :due_by)

    The map would be:
    %{
      1 => [:inclass_activity, :due_by, :read_by],
      3 => [:due_by, :read_by],
      6 => [:read_by, :due_by],
      7 => [:read_by, :due_by],
      10 => [:due_by]
    }
  """

  def contained_scheduling_types(full_hierarchy) do
    contained_scheduling_types(full_hierarchy["children"], [], full_hierarchy["resource_id"], %{})
  end

  def thin_hierarchy(hierarchy, fields_to_keep, filter_fn \\ fn _ -> true end)

  def thin_hierarchy(hierarchy, fields_to_keep, filter_fn)
      when is_map(hierarchy) do
    if filter_fn.(hierarchy) do
      hierarchy
      |> Map.take(fields_to_keep)
      |> Map.replace("children", thin_hierarchy(hierarchy["children"], fields_to_keep, filter_fn))
    else
      nil
    end
  end

  def thin_hierarchy(hierarchy, fields_to_keep, filter_fn)
      when is_list(hierarchy) do
    hierarchy
    |> Enum.map(fn node -> thin_hierarchy(node, fields_to_keep, filter_fn) end)
    |> Enum.reject(&is_nil/1)
  end

  @container_resource_type_id Oli.Resources.ResourceType.id_for_container()
  defp contained_scheduling_types([] = _children, acum_list, current_container_id, result_map),
    do:
      Map.put(
        result_map,
        current_container_id,
        acum_list
        |> List.flatten()
        |> Enum.uniq()
      )

  defp contained_scheduling_types(
         [%{"children" => [], "resource_type_id" => @container_resource_type_id} = child | rest],
         acum_list,
         current_container_id,
         result_map
       ) do
    # an edge case of a container with no children
    contained_scheduling_types(
      rest,
      acum_list,
      current_container_id,
      Map.put(result_map, child["resource_id"], [])
    )
  end

  defp contained_scheduling_types(
         [%{"children" => []} = child | rest],
         acum_list,
         current_container_id,
         result_map
       ) do
    # a page case
    contained_scheduling_types(
      rest,
      [child["section_resource"].scheduling_type | acum_list],
      current_container_id,
      result_map
    )
  end

  defp contained_scheduling_types([child | rest], acum_list, current_container_id, result_map) do
    # a container with children case
    result_map_for_current_child =
      contained_scheduling_types(child["children"], [], child["resource_id"], %{})

    contained_scheduling_types(
      rest,
      [Map.get(result_map_for_current_child, child["resource_id"]) | acum_list],
      current_container_id,
      Map.merge(result_map, result_map_for_current_child)
    )
  end
end
