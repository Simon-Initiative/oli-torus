defmodule Oli.Delivery.HierarchyTest do
  use Oli.DataCase

  alias Oli.Delivery.Hierarchy
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

      assert Hierarchy.find_in_hierarchy(hierarchy, nested_page_one_node.uuid) == nil
    end

    test "move_node/3", %{hierarchy: hierarchy, nested_page_one_node: nested_page_one_node} do
      node = Hierarchy.find_in_hierarchy(hierarchy, nested_page_one_node.uuid)

      hierarchy = Hierarchy.move_node(hierarchy, node, hierarchy.uuid)

      assert Hierarchy.find_in_hierarchy(hierarchy, nested_page_one_node.uuid) != nil
      assert node in hierarchy.children
    end

    test "add_materials_to_hierarchy/4", %{
      hierarchy: hierarchy,
      unit_node: unit_node
    } do
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
  end
end
