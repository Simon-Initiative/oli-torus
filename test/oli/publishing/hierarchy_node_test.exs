defmodule Oli.Publishing.HierarchyNodeTest do
  use Oli.DataCase

  alias Oli.Publishing.HierarchyNode
  alias Oli.Publishing.DeliveryResolver

  describe "hierarchy node" do
    setup do
      map = Seeder.base_project_with_resource4()

      hierarchy = DeliveryResolver.full_hierarchy(map.section_1.slug)

      Map.put(map, :hierarchy, hierarchy)
    end

    test "flatten_pages/1", %{hierarchy: hierarchy} do
      flattened = HierarchyNode.flatten_pages(hierarchy)

      assert Enum.map(flattened, & &1.section_resource.slug) == [
               "page_one",
               "page_two",
               "nested_page_one",
               "nested_page_two"
             ]
    end

    test "flatten_hierarchy/1", %{hierarchy: hierarchy} do
      flattened = HierarchyNode.flatten_hierarchy(hierarchy)

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
      nested_revision1: nested_revision1
    } do
      root = HierarchyNode.find_in_hierarchy(hierarchy, "root_container")
      node = HierarchyNode.find_in_hierarchy(hierarchy, "page_one")
      nested_node = HierarchyNode.find_in_hierarchy(hierarchy, "nested_page_one")

      assert root.resource_id == hierarchy.resource_id
      assert node.resource_id == revision1.resource_id
      assert nested_node.resource_id == nested_revision1.resource_id
    end

    test "find_and_remove_node/2", %{hierarchy: hierarchy} do
      assert HierarchyNode.find_in_hierarchy(hierarchy, "nested_page_one") != nil

      hierarchy = HierarchyNode.find_and_remove_node(hierarchy, "nested_page_one")

      assert HierarchyNode.find_in_hierarchy(hierarchy, "nested_page_one") == nil
    end

    test "move_node/3", %{hierarchy: hierarchy} do
      node = HierarchyNode.find_in_hierarchy(hierarchy, "nested_page_one")

      hierarchy = HierarchyNode.move_node(hierarchy, node, hierarchy.slug)

      assert HierarchyNode.find_in_hierarchy(hierarchy, "nested_page_one") != nil
      assert node in hierarchy.children
    end
  end
end
