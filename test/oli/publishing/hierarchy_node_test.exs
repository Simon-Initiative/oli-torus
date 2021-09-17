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
  end
end
