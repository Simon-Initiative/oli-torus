defmodule Oli.Delivery.HierarchyTest do
  use Oli.DataCase

  alias Oli.Delivery.Hierarchy
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Publishing
  alias Oli.Publishing.DeliveryResolver

  describe "hierarchy node" do
    setup do
      map = Seeder.base_project_with_resource4()

      hierarchy = DeliveryResolver.full_hierarchy(map.section_1.slug)

      page_one_node = hierarchy.children |> Enum.at(0)
      page_two_node = hierarchy.children |> Enum.at(1)
      unit_node = hierarchy.children |> Enum.at(2)
      nested_page_one_node = hierarchy.children |> Enum.at(2) |> Map.get(:children) |> Enum.at(0)
      nested_page_two_node = hierarchy.children |> Enum.at(2) |> Map.get(:children) |> Enum.at(1)

      map
      |> Map.put(:hierarchy, hierarchy)
      |> Map.put(:page_one_node, page_one_node)
      |> Map.put(:page_two_node, page_two_node)
      |> Map.put(:unit_node, unit_node)
      |> Map.put(:nested_page_one_node, nested_page_one_node)
      |> Map.put(:nested_page_two_node, nested_page_two_node)
    end

    test "build_navigation_link_map/1", %{
      hierarchy: hierarchy,
      page_one_node: node1,
      page_two_node: node2,
      unit_node: unit_node,
      nested_page_one_node: node3,
      nested_page_two_node: node4
    } do
      link_map = Hierarchy.build_navigation_link_map(hierarchy)

      get = fn n -> Map.get(link_map, n.revision.resource_id |> Integer.to_string()) end

      # verify that all four pages exist within the link map
      assert 5 == Map.keys(link_map) |> Enum.count()

      # verify that the links are set up correctly and that the slugs and titles
      # are present and correct
      assert get.(node1)["prev"] == nil
      assert get.(node1)["next"] == Integer.to_string(node2.revision.resource_id)
      assert get.(node1)["slug"] == node1.revision.slug
      assert get.(node1)["title"] == node1.revision.title

      assert get.(node2)["prev"] == Integer.to_string(node1.revision.resource_id)
      assert get.(node2)["next"] == Integer.to_string(unit_node.revision.resource_id)
      assert get.(node2)["slug"] == node2.revision.slug
      assert get.(node2)["title"] == node2.revision.title

      assert get.(unit_node)["prev"] == Integer.to_string(node2.revision.resource_id)
      assert get.(unit_node)["next"] == Integer.to_string(node3.revision.resource_id)
      assert get.(unit_node)["slug"] == unit_node.revision.slug
      assert get.(unit_node)["title"] == unit_node.revision.title

      assert get.(node3)["prev"] == Integer.to_string(unit_node.revision.resource_id)
      assert get.(node3)["next"] == Integer.to_string(node4.revision.resource_id)
      assert get.(node3)["slug"] == node3.revision.slug
      assert get.(node3)["title"] == node3.revision.title

      assert get.(node4)["prev"] == Integer.to_string(node3.revision.resource_id)
      assert get.(node4)["next"] == nil
      assert get.(node4)["slug"] == node4.revision.slug
      assert get.(node4)["title"] == node4.revision.title
    end

    test "flatten_pages/1", %{hierarchy: hierarchy} do
      flattened = Hierarchy.flatten_pages(hierarchy)

      assert Enum.map(flattened, & &1.section_resource.slug) == [
               "page_one",
               "page_two",
               "nested_page_one",
               "nested_page_two"
             ]
    end

    test "flatten_hierarchy/1", %{hierarchy: hierarchy} do
      flattened = Hierarchy.flatten_hierarchy(hierarchy)

      assert Enum.map(flattened, & &1.section_resource.slug) == [
               "root_container",
               "page_one",
               "page_two",
               "unit_1",
               "nested_page_one",
               "nested_page_two"
             ]
    end

    test "find_in_hierarchy/2", %{
      hierarchy: hierarchy,
      revision1: revision1,
      nested_revision1: nested_revision1,
      page_one_node: page_one_node,
      nested_page_one_node: nested_page_one_node
    } do
      root = Hierarchy.find_in_hierarchy(hierarchy, hierarchy.uuid)

      node = Hierarchy.find_in_hierarchy(hierarchy, page_one_node.uuid)

      nested_node =
        Hierarchy.find_in_hierarchy(
          hierarchy,
          nested_page_one_node.uuid
        )

      assert root.resource_id == hierarchy.resource_id
      assert node.resource_id == revision1.resource_id
      assert nested_node.resource_id == nested_revision1.resource_id
    end

    test "find_and_remove_node/2", %{
      hierarchy: hierarchy,
      nested_page_one_node: nested_page_one_node
    } do
      assert Hierarchy.find_in_hierarchy(hierarchy, nested_page_one_node.uuid) != nil

      hierarchy = Hierarchy.find_and_remove_node(hierarchy, nested_page_one_node.uuid)
        |> Hierarchy.finalize()

      assert Hierarchy.find_in_hierarchy(hierarchy, nested_page_one_node.uuid) == nil
    end

    test "move_node/3", %{hierarchy: hierarchy, nested_page_one_node: nested_page_one_node} do
      node = Hierarchy.find_in_hierarchy(hierarchy, nested_page_one_node.uuid)

      hierarchy = Hierarchy.move_node(hierarchy, node, hierarchy.uuid)
        |> Hierarchy.finalize()

      assert Hierarchy.find_in_hierarchy(hierarchy, nested_page_one_node.uuid) != nil
      assert Enum.find(hierarchy.children, fn c -> c.uuid == node.uuid end) != nil
    end

    test "add_materials_to_hierarchy/4", %{
      hierarchy: hierarchy,
      unit_node: unit_node
    } do
      # create multiple other projects to add materials from
      %{pub2: p2_pub, page1: p2_page1} = Seeder.base_project_with_resource4()
      %{pub2: p3_pub, page1: p3_page1} = Seeder.base_project_with_resource4()

      selection = [{p2_pub.id, p2_page1.id}, {p3_pub.id, p3_page1.id}]

      publication_ids =
        selection
        |> Enum.reduce(%{}, fn {pub_id, _resource_id}, acc ->
          Map.put(acc, pub_id, true)
        end)
        |> Map.keys()

      published_resources_by_resource_id_by_pub =
        Publishing.get_published_resources_for_publications(publication_ids)

      hierarchy =
        Hierarchy.add_materials_to_hierarchy(
          hierarchy,
          unit_node,
          selection,
          published_resources_by_resource_id_by_pub
        )
        |> Hierarchy.finalize()

      assert hierarchy.children |> Enum.count() == 3
      assert hierarchy.children |> Enum.at(2) |> Map.get(:children) |> Enum.count() == 4

      assert hierarchy.children
             |> Enum.at(2)
             |> Map.get(:children)
             |> Enum.at(2)
             |> Map.get(:resource_id) == p2_page1.id

      assert hierarchy.children
             |> Enum.at(2)
             |> Map.get(:children)
             |> Enum.at(3)
             |> Map.get(:resource_id) == p3_page1.id
    end

    test "purge_duplicate_resources/1", %{
      hierarchy: hierarchy,
      unit_node: unit_node,
      page_one_node: page_one_node,
      page1: page1,
      nested_page1: nested_page1
    } do
      unit_node_with_duplicate_page_one = %HierarchyNode{
        unit_node
        | children: [page_one_node | unit_node.children]
      }

      hierarchy = Hierarchy.find_and_update_node(hierarchy, unit_node_with_duplicate_page_one)
        |> Hierarchy.finalize()

      assert hierarchy.children
             |> Enum.at(2)
             |> Map.get(:children)
             |> Enum.count() == 3

      assert hierarchy.children
             |> Enum.at(2)
             |> Map.get(:children)
             |> Enum.at(0)
             |> Map.get(:resource_id) == page1.id

      assert hierarchy.children
             |> Enum.at(2)
             |> Map.get(:children)
             |> Enum.at(1)
             |> Map.get(:resource_id) == nested_page1.id

      hierarchy = Hierarchy.purge_duplicate_resources(hierarchy)
        |> Hierarchy.finalize()

      assert hierarchy.children
             |> Enum.at(2)
             |> Map.get(:children)
             |> Enum.count() == 2

      assert hierarchy.children
             |> Enum.at(2)
             |> Map.get(:children)
             |> Enum.at(0)
             |> Map.get(:resource_id) == nested_page1.id
    end
  end
end
