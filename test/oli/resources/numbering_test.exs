defmodule Oli.Resources.NumberingTest do
  use Oli.DataCase

  alias Oli.Resources.Revision
  alias Oli.Resources.Numbering
  alias Oli.Utils.HierarchyNode
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
        %HierarchyNode{
          title: "Unit 1",
          children: [
            # HierarchyNode makes everything a container, so we're just simulating a page here
            %HierarchyNode{title: "Page 1", slug: "page_1"},
            %HierarchyNode{
              title: "Module 2",
              children: [
                %HierarchyNode{
                  title: "Section 1",
                  children: [
                    # HierarchyNode makes everything a container, so we're just simulating a page here
                    %HierarchyNode{title: "Page 2", slug: "page_2"}
                  ]
                },
                %HierarchyNode{title: "Section 2"},
                %HierarchyNode{title: "Section 3"}
              ]
            },
            %HierarchyNode{
              title: "Module 3",
              children: [
                %HierarchyNode{title: "Section 4"},
                %HierarchyNode{title: "Section 5"},
                %HierarchyNode{title: "Section 6"}
              ]
            }
          ]
        },
        %HierarchyNode{
          title: "Unit 2"
        }
      ])
    end

    # test "path_from_root_to/2 returns the root container as the first item in the path", %{
    #   project: project,
    #   container: %{revision: root}
    # } do
    #   {:ok, path_1} = Numbering.path_from_root_to(project.slug, "page_1", root)
    #   {:ok, path_2} = Numbering.path_from_root_to(project.slug, "page_2", root)

    #   [head_1 | _rest] = path_1
    #   [head_2 | _rest] = path_2

    #   assert head_1.slug == root.slug
    #   assert head_2.slug == root.slug
    # end

    # test "path_from_root_to/2 returns the resource as the last item in the path", %{
    #   project: project,
    #   container: %{revision: root}
    # } do
    #   {:ok, path_1} = Numbering.path_from_root_to(project.slug, "page_1", root)
    #   {:ok, path_2} = Numbering.path_from_root_to(project.slug, "page_2", root)

    #   assert List.last(path_1).slug == "page_1"
    #   assert List.last(path_2).slug == "page_2"
    # end

    # test "path_from_root_to/2 returns the full path from the root container to the resource", %{
    #   project: project,
    #   container: %{revision: root}
    # } do
    #   {:ok, path_2} = Numbering.path_from_root_to(project.slug, "page_2", root)
    #   correct_titles = [root.title, "Unit 1", "Module 1", "Section 1", "Page 2"]

    #   path_2
    #   |> Enum.map(& &1.title)
    #   |> Enum.zip(correct_titles)
    #   |> Enum.each(fn {path_title, correct_title} ->
    #     assert path_title == correct_title end)
    # end

    test "number_full_tree/2 numbers the containers correctly", %{
      project: project,
      container: %{revision: root}
    } do

      # do the numbering, then programatically compare it to the titles of the
      # containers, which contain the correct numbering and level names
      Numbering.number_full_tree(root, fetch_hierarchy(project.slug))
      |> Enum.to_list()
      |> Enum.map(&elem(&1, 1))
      |> Enum.filter(& !Regex.match?(~r|page|, &1.container.slug))
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
