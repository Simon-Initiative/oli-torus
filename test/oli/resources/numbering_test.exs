defmodule Oli.Resources.NumberingTest do
  use Oli.DataCase

  alias Oli.Resources.Numbering
  alias Oli.Utils.HierarchyNode

  describe "container numbering" do

    setup do
      Seeder.base_project_with_resource2()
        |> Seeder.create_hierarchy([%HierarchyNode{
          title: "Unit 1",
          children: [
            %HierarchyNode{
              title: "Module 1",
              children: [
                %HierarchyNode{title: "Section 1"},
                %HierarchyNode{title: "Section 2"},
                %HierarchyNode{title: "Section 3"},
              ]
            },
            %HierarchyNode{
              title: "Module 2",
              children: [
                %HierarchyNode{title: "Section 4"},
                %HierarchyNode{title: "Section 5"},
                %HierarchyNode{title: "Section 6"},
              ]
            }
          ]
        },
        %HierarchyNode{
          title: "Unit 2"
        }])

    end


    test "number_full_tree/2 numbers the containers correctly", %{project: project, container: %{revision: root}} do

      hierarchy_nodes = Numbering.fetch_hierarchy(project.slug)

      # do the numbering, then programatically compare it to the titles of the
      # containers, which contain the correct numbering and level names
      Numbering.number_full_tree(root, hierarchy_nodes)
      |> Enum.each(fn n ->

        level = case n.level do
          1 -> "Unit"
          2 -> "Module"
          3 -> "Section"
        end

        assert Numbering.number_prefix(n) == n.container.title
        assert n.container.title == "#{level} #{n.count}"

      end)

    end

  end

end
