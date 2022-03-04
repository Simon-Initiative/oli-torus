defmodule Oli.Delivery.PreviousNextIndexTest do
  use Oli.DataCase

  alias Oli.Delivery.Sections
  alias Oli.Delivery.PreviousNextIndex
  alias Oli.Publishing.DeliveryResolver

  describe "previous next index" do
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
      page_two_node: node2,
      unit_node: unit_node,
      nested_page_one_node: node3,
      nested_page_two_node: node4,
      section_1: section
    } do
      assert is_nil(section.previous_next_index)

      {:ok, {_previous, next, _}, _} =
        PreviousNextIndex.retrieve(section, node2.revision.resource_id)

      # verify that the links are set up correctly and that the slugs and titles
      # are present and correct. Containers should render as pages.
      assert next["slug"] == unit_node.revision.slug

      {:ok, {previous, next, _}, _} =
        PreviousNextIndex.retrieve(section, unit_node.revision.resource_id)

      assert previous["slug"] == node2.revision.slug
      assert next["slug"] == node3.revision.slug

      {:ok, {previous, next, _}, _} =
        PreviousNextIndex.retrieve(section, node3.revision.resource_id)

      assert previous["slug"] == unit_node.revision.slug
      assert next["slug"] == node4.revision.slug

      section = Sections.get_section_by_slug(section.slug)

      refute is_nil(section.previous_next_index)
    end
  end
end
