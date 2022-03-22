defmodule Oli.Resources.NumberingTest do
  use Oli.DataCase

  alias Oli.Resources.Numbering
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Delivery.Sections
  alias Oli.Publishing
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Hierarchy

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
      project: project
    } do
      revisions_by_id =
        AuthoringResolver.all_revisions_in_hierarchy(project.slug)
        |> Enum.reduce(%{}, fn rev, acc -> Map.put(acc, rev.id, rev) end)

      # do the numbering, then programatically compare it to the titles of the
      # containers, which contain the correct numbering and level names
      # Numbering.number_tree_from(root, AuthoringResolver.all_revisions_in_hierarchy(project.slug))
      Numbering.number_full_tree(AuthoringResolver, project.slug)
      |> Enum.to_list()
      |> Enum.filter(fn {id, _n} ->
        !Regex.match?(~r|page|, revisions_by_id[id].slug) &&
          revisions_by_id[id].title != "Root container"
      end)
      |> Enum.each(fn {id, n} ->
        revision = revisions_by_id[id]

        level =
          case n.level do
            1 -> "Unit"
            2 -> "Module"
            _ -> "Section"
          end

        assert Numbering.prefix(n) == revision.title
        assert revision.title == "#{level} #{n.index}"
      end)
    end

    test "path_from_root_to/2", %{project: project, institution: institution} do
      # Publish the current state of our test project
      {:ok, pub1} = Publishing.publish_project(project, "some changes")

      {:ok, section} =
        Sections.create_section(%{
          title: "1",
          timezone: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: institution.id,
          base_project_id: project.id
        })
        |> then(fn {:ok, section} -> section end)
        |> Sections.create_section_resources(pub1)

      hierarchy = DeliveryResolver.full_hierarchy(section.slug)

      node =
        Enum.at(
          Enum.at(Enum.at(Enum.at(hierarchy.children, 0).children, 1).children, 0).children,
          0
        )

      {:ok, path_nodes} = Numbering.path_from_root_to(hierarchy, node)

      path_titles = Enum.map(path_nodes, fn n -> n.revision.title end)

      assert path_titles == ["Root Container", "Unit 1", "Module 2", "Section 1", "Page 2"]
    end

    test "renumber_hierarchy/1", %{project: project, institution: institution} do
      # Publish the current state of our test project
      {:ok, pub1} = Publishing.publish_project(project, "some changes")

      {:ok, section} =
        Sections.create_section(%{
          title: "1",
          timezone: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: institution.id,
          base_project_id: project.id
        })
        |> then(fn {:ok, section} -> section end)
        |> Sections.create_section_resources(pub1)

      hierarchy = DeliveryResolver.full_hierarchy(section.slug)

      page_1_node = hierarchy.children |> Enum.at(0) |> Map.get(:children) |> Enum.at(0)
      section_2_node = hierarchy.children |> Enum.at(0) |> Map.get(:children) |> Enum.at(1) |> Map.get(:children) |> Enum.at(1)

      hierarchy = Hierarchy.move_node(hierarchy, page_1_node, section_2_node.uuid)

      module_2_node = hierarchy.children |> Enum.at(0) |> Map.get(:children) |> Enum.at(0)
      unit_2_node = hierarchy.children |> Enum.at(1)

      hierarchy = Hierarchy.move_node(hierarchy, module_2_node, unit_2_node.uuid)
        |> Hierarchy.finalize()

      assert hierarchy.numbering.level == 0
      assert hierarchy.numbering.index == 1

      assert (hierarchy.children |> Enum.at(0)).numbering.level == 1
      assert (hierarchy.children |> Enum.at(0)).numbering.index == 1

      assert (hierarchy.children |> Enum.at(0) |> Map.get(:children) |> Enum.at(0)).numbering.level == 2
      assert (hierarchy.children |> Enum.at(0) |> Map.get(:children) |> Enum.at(0)).numbering.index == 1

      assert (hierarchy.children |> Enum.at(0) |> Map.get(:children) |> Enum.at(0) |> Map.get(:children) |> Enum.at(0)).numbering.level == 3
      assert (hierarchy.children |> Enum.at(0) |> Map.get(:children) |> Enum.at(0) |> Map.get(:children) |> Enum.at(0)).numbering.index == 1
      assert (hierarchy.children |> Enum.at(0) |> Map.get(:children) |> Enum.at(0) |> Map.get(:children) |> Enum.at(1)).numbering.level == 3
      assert (hierarchy.children |> Enum.at(0) |> Map.get(:children) |> Enum.at(0) |> Map.get(:children) |> Enum.at(1)).numbering.index == 2
      assert (hierarchy.children |> Enum.at(0) |> Map.get(:children) |> Enum.at(0) |> Map.get(:children) |> Enum.at(2)).numbering.level == 3
      assert (hierarchy.children |> Enum.at(0) |> Map.get(:children) |> Enum.at(0) |> Map.get(:children) |> Enum.at(2)).numbering.index == 3

      assert (hierarchy.children |> Enum.at(1)).numbering.level == 1
      assert (hierarchy.children |> Enum.at(1)).numbering.index == 2

      assert (hierarchy.children |> Enum.at(1) |> Map.get(:children) |> Enum.at(0) |> Map.get(:children) |> Enum.at(0)).numbering.level == 3
      assert (hierarchy.children |> Enum.at(1) |> Map.get(:children) |> Enum.at(0) |> Map.get(:children) |> Enum.at(0)).numbering.index == 4

      assert (hierarchy.children |> Enum.at(1) |> Map.get(:children) |> Enum.at(0) |> Map.get(:children) |> Enum.at(0) |> Map.get(:children) |> Enum.at(0)).numbering.level == 4
      assert (hierarchy.children |> Enum.at(1) |> Map.get(:children) |> Enum.at(0) |> Map.get(:children) |> Enum.at(0) |> Map.get(:children) |> Enum.at(0)).numbering.index == 1

      assert (hierarchy.children |> Enum.at(1) |> Map.get(:children) |> Enum.at(0) |> Map.get(:children) |> Enum.at(1)).numbering.level == 3
      assert (hierarchy.children |> Enum.at(1) |> Map.get(:children) |> Enum.at(0) |> Map.get(:children) |> Enum.at(1)).numbering.index == 5
      assert (hierarchy.children |> Enum.at(1) |> Map.get(:children) |> Enum.at(0) |> Map.get(:children) |> Enum.at(2)).numbering.level == 3
      assert (hierarchy.children |> Enum.at(1) |> Map.get(:children) |> Enum.at(0) |> Map.get(:children) |> Enum.at(2)).numbering.index == 6

    end
  end
end
