defmodule Oli.Delivery.Sections.DisplayNumberingTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Delivery.Sections.DisplayNumbering
  alias Oli.Delivery.Sections.Section
  alias Oli.Resources.Numbering
  alias Oli.Resources.ResourceType

  test "renumbers visible containers by level while skipping unnumbered unit subtrees" do
    section = %Section{unnumbered_unit_ids: [11]}
    hierarchy = hierarchy_node_tree()

    decorated = DisplayNumbering.decorate_hierarchy(section, hierarchy)

    [unit_1, unit_2, unit_3] = decorated.children
    [module_1] = unit_1.children
    [hidden_module] = unit_2.children
    [module_3] = unit_3.children

    assert decorated.display_numbering.index == 1
    assert unit_1.display_numbering.index == 1
    assert module_1.display_numbering.index == 1

    assert unit_2.display_numbering == nil
    assert hidden_module.display_numbering == nil

    assert unit_3.display_numbering.index == 2
    assert module_3.display_numbering.index == 2
  end

  test "renumbers visible map containers by level while skipping unnumbered unit subtrees" do
    section = %Section{unnumbered_unit_ids: [11]}
    hierarchy = map_tree()

    decorated = DisplayNumbering.decorate_hierarchy(section, hierarchy)

    [unit_1, unit_2, unit_3] = decorated["children"]
    [module_1] = unit_1["children"]
    [hidden_module] = unit_2["children"]
    [module_3] = unit_3["children"]

    assert decorated["display_numbering"]["index"] == 1
    assert unit_1["display_numbering"]["index"] == 1
    assert module_1["display_numbering"]["index"] == 1

    assert unit_2["display_numbering"] == nil
    assert hidden_module["display_numbering"] == nil

    assert unit_3["display_numbering"]["index"] == 2
    assert module_3["display_numbering"]["index"] == 2
  end

  test "returns the original hierarchy unchanged when there are no unnumbered units" do
    section = %Section{unnumbered_unit_ids: []}
    hierarchy = hierarchy_node_tree()

    assert DisplayNumbering.decorate_hierarchy(section, hierarchy) == hierarchy
  end

  defp hierarchy_node_tree do
    %HierarchyNode{
      resource_id: 1,
      revision: %{resource_type_id: ResourceType.id_for_container(), title: "Curriculum"},
      numbering: %Numbering{level: 0, index: 1},
      children: [
        unit_node(10, 1, [module_node(20, 1)]),
        unit_node(11, 2, [module_node(21, 2)]),
        unit_node(12, 3, [module_node(22, 3)])
      ]
    }
  end

  defp unit_node(resource_id, index, children) do
    %HierarchyNode{
      resource_id: resource_id,
      revision: %{resource_type_id: ResourceType.id_for_container(), title: "Unit #{index}"},
      numbering: %Numbering{level: 1, index: index},
      children: children
    }
  end

  defp module_node(resource_id, index) do
    %HierarchyNode{
      resource_id: resource_id,
      revision: %{resource_type_id: ResourceType.id_for_container(), title: "Module #{index}"},
      numbering: %Numbering{level: 2, index: index},
      children: [
        %HierarchyNode{
          resource_id: resource_id + 100,
          revision: %{resource_type_id: ResourceType.id_for_page(), title: "Page #{index}"},
          numbering: %Numbering{level: 2, index: index},
          children: []
        }
      ]
    }
  end

  defp map_tree do
    %{
      "resource_id" => 1,
      "resource_type_id" => ResourceType.id_for_container(),
      "numbering" => %{"level" => 0, "index" => 1},
      "children" => [
        unit_map(10, 1, [module_map(20, 1)]),
        unit_map(11, 2, [module_map(21, 2)]),
        unit_map(12, 3, [module_map(22, 3)])
      ]
    }
  end

  defp unit_map(resource_id, index, children) do
    %{
      "resource_id" => resource_id,
      "resource_type_id" => ResourceType.id_for_container(),
      "numbering" => %{"level" => 1, "index" => index},
      "children" => children
    }
  end

  defp module_map(resource_id, index) do
    %{
      "resource_id" => resource_id,
      "resource_type_id" => ResourceType.id_for_container(),
      "numbering" => %{"level" => 2, "index" => index},
      "children" => [
        %{
          "resource_id" => resource_id + 100,
          "resource_type_id" => ResourceType.id_for_page(),
          "numbering" => %{"level" => 2, "index" => index},
          "children" => []
        }
      ]
    }
  end
end
