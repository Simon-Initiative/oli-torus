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

  describe "retrieve/3 when there are containers to skip" do
    test "returns no previous or next when the current resource is not in the index map" do
      assert {:ok, {nil, nil, nil}, %{}} == PreviousNextIndex.retrieve(%{}, 1, skip: [:unit])
    end

    test "returns closest navigable resource when next or prev resource should be skipped" do
      # Page 1, Unit 2, Page 3, Section 4, Page 5
      {prev_next_index, _, _} =
        attach_next("page")
        |> attach_next("unit")
        |> attach_next("page")
        |> attach_next("section")
        |> attach_next("page")

      # Get Page 3, and its prev and next
      {:ok, {prev, next, current}, _} =
        PreviousNextIndex.retrieve(prev_next_index, 3, skip: [:unit, :section])

      # Current is Page 3
      assert current["id"] == "3"
      assert current["title"] == "page 3"
      assert current["type"] == "page"

      # Prev is Page 1, it skips Unit 2
      assert prev["id"] == "1"
      assert prev["title"] == "page 1"
      assert prev["type"] == "page"

      # Next is Page 5, it skips Section 4
      assert next["id"] == "5"
      assert next["title"] == "page 5"
      assert next["type"] == "page"
    end
  end

  defp attach_next(type), do: attach_next({%{}, nil, 1}, type)

  defp attach_next({prev_next_index, current, id}, type) do
    {level, resource_type} =
      case type do
        "page" -> {"1", "page"}
        "unit" -> {"1", "container"}
        "module" -> {"2", "container"}
        _ -> {"3", "container"}
      end

    next =
      %{
        "id" => "#{id}",
        "index" => "#{id}",
        "prev" => current["id"],
        "next" => nil,
        "slug" => "#{type}_#{id}",
        "title" => "#{type} #{id}",
        "children" => [],
        "type" => resource_type,
        "level" => level
      }

    prev_next_index =
      if current do
        current = Map.put(current, "next", "#{id}")
        Map.put(prev_next_index, current["id"], current)
      else
        prev_next_index
      end
      |> Map.put(next["id"], next)

    {prev_next_index, next, id + 1}
  end
end
