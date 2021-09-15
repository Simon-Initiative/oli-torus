defmodule Oli.Resources.NumberingTest do
  use Oli.DataCase

  alias Oli.Resources.Numbering
  alias Oli.Publishing.AuthoringResolver

  describe "container numbering" do
    setup do
      Seeder.base_project_with_resource2()
      |> Seeder.create_hierarchy([
        %{
          title: "Unit 1",
          children: [
            #  makes everything a container, so we're just simulating a page here
            %{title: "Page 1", slug: "page_1", children: []},
            %{
              title: "Module 2",
              children: [
                %{
                  title: "Section 1",
                  children: [
                    #  makes everything a container, so we're just simulating a page here
                    %{title: "Page 2", slug: "page_2", children: []}
                  ]
                },
                %{title: "Section 2", children: []},
                %{title: "Section 3", children: []}
              ]
            },
            %{
              title: "Module 3",
              children: [
                %{title: "Section 4", children: []},
                %{title: "Section 5", children: []},
                %{title: "Section 6", children: []}
              ]
            }
          ]
        },
        %{
          title: "Unit 2",
          children: []
        }
      ])
    end

    test "number_tree_from/2 numbers the containers correctly", %{
      project: project,
      container: %{revision: root}
    } do
      # do the numbering, then programatically compare it to the titles of the
      # containers, which contain the correct numbering and level names
      # Numbering.number_tree_from(root, AuthoringResolver.all_revisions_in_hierarchy(project.slug))
      Numbering.number_full_tree(AuthoringResolver, project.slug)
      |> Enum.to_list()
      |> Enum.map(&elem(&1, 1))
      |> Enum.filter(
        &(!Regex.match?(~r|page|, &1.revision.slug) && &1.revision.title != "Root container")
      )
      |> Enum.each(fn n ->
        level =
          case n.level do
            1 -> "Unit"
            2 -> "Module"
            _ -> "Section"
          end

        assert Numbering.prefix(n) == n.revision.title
        assert n.revision.title == "#{level} #{n.index}"
      end)
    end

    test "renumber_hierarchy/1" do
      throw("TODO")
    end

    test "path_from_root_to/2" do
      throw("TODO")
    end
  end
end
