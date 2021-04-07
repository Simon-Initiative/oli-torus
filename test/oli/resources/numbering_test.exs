defmodule Oli.Resources.NumberingTest do
  use Oli.DataCase

  alias Oli.Resources.Revision
  alias Oli.Resources.Numbering
  alias Oli.Repo

  defp fetch_hierarchy(project_slug) do
    page_id = Oli.Resources.ResourceType.get_id_by_type("page")
    container_id = Oli.Resources.ResourceType.get_id_by_type("container")

    Repo.all(
      from m in "published_resources",
        join: rev in Revision,
        on: rev.id == m.revision_id,
        join: p in "publications",
        on: p.id == m.publication_id,
        join: c in "projects",
        on: p.project_id == c.id,
        where:
          p.published == false and
            (rev.resource_type_id == ^page_id or rev.resource_type_id == ^container_id) and
            c.slug == ^project_slug,
        select: rev
    )
  end

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
      Numbering.number_tree_from(root, fetch_hierarchy(project.slug))
      |> Enum.to_list()
      |> Enum.map(&elem(&1, 1))
      |> Enum.filter(&(!Regex.match?(~r|page|, &1.container.slug)))
      |> Enum.each(fn n ->
        level =
          case n.level do
            1 -> "Unit"
            2 -> "Module"
            3 -> "Section"
          end

        assert Numbering.prefix(n) == n.container.title
        assert n.container.title == "#{level} #{n.count}"
      end)
    end
  end
end
