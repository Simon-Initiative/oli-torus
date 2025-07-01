defmodule Oli.Delivery.HierarchyTest do
  use Oli.DataCase

  alias Oli.Delivery.Hierarchy
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Delivery.Sections
  alias Oli.Publishing
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.ResourceType

  import Oli.Factory

  describe "hierarchy node" do
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
      hierarchy: hierarchy,
      page_one_node: node1,
      page_two_node: node2,
      unit_node: unit_node,
      nested_page_one_node: node3,
      nested_page_two_node: node4
    } do
      link_map = Hierarchy.build_navigation_link_map(hierarchy)

      get = fn n -> Map.get(link_map, n.revision.resource_id |> Integer.to_string()) end

      # verify that all four pages exist within the link map
      assert 5 == Map.keys(link_map) |> Enum.count()

      # verify that the links are set up correctly and that the slugs and titles
      # are present and correct
      assert get.(node1)["prev"] == nil
      assert get.(node1)["next"] == Integer.to_string(node2.revision.resource_id)
      assert get.(node1)["slug"] == node1.revision.slug
      assert get.(node1)["title"] == node1.revision.title

      assert get.(node2)["prev"] == Integer.to_string(node1.revision.resource_id)
      assert get.(node2)["next"] == Integer.to_string(unit_node.revision.resource_id)
      assert get.(node2)["slug"] == node2.revision.slug
      assert get.(node2)["title"] == node2.revision.title

      assert get.(unit_node)["prev"] == Integer.to_string(node2.revision.resource_id)
      assert get.(unit_node)["next"] == Integer.to_string(node3.revision.resource_id)
      assert get.(unit_node)["slug"] == unit_node.revision.slug
      assert get.(unit_node)["title"] == unit_node.revision.title

      assert get.(node3)["prev"] == Integer.to_string(unit_node.revision.resource_id)
      assert get.(node3)["next"] == Integer.to_string(node4.revision.resource_id)
      assert get.(node3)["slug"] == node3.revision.slug
      assert get.(node3)["title"] == node3.revision.title

      assert get.(node4)["prev"] == Integer.to_string(node3.revision.resource_id)
      assert get.(node4)["next"] == nil
      assert get.(node4)["slug"] == node4.revision.slug
      assert get.(node4)["title"] == node4.revision.title
    end

    test "flatten_pages/1", %{hierarchy: hierarchy} do
      flattened = Hierarchy.flatten_pages(hierarchy)

      assert Enum.map(flattened, & &1.section_resource.slug) == [
               "page_one",
               "page_two",
               "nested_page_one",
               "nested_page_two"
             ]
    end

    test "flatten_hierarchy/1", %{hierarchy: hierarchy} do
      flattened = Hierarchy.flatten_hierarchy(hierarchy)

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
      nested_revision1: nested_revision1,
      page_one_node: page_one_node,
      nested_page_one_node: nested_page_one_node
    } do
      root = Hierarchy.find_in_hierarchy(hierarchy, hierarchy.uuid)

      node = Hierarchy.find_in_hierarchy(hierarchy, page_one_node.uuid)

      nested_node =
        Hierarchy.find_in_hierarchy(
          hierarchy,
          nested_page_one_node.uuid
        )

      assert root.resource_id == hierarchy.resource_id
      assert node.resource_id == revision1.resource_id
      assert nested_node.resource_id == nested_revision1.resource_id
    end

    test "find_parent_in_hierarchy/2", %{
      hierarchy: hierarchy,
      unit_node: unit_node,
      nested_page_one_node: nested_page_one_node
    } do
      # using uuid
      nested_node_parent =
        Hierarchy.find_parent_in_hierarchy(
          hierarchy,
          nested_page_one_node.uuid
        )

      assert nested_node_parent.resource_id == unit_node.resource_id

      # using find_by fn
      nested_node_parent =
        Hierarchy.find_parent_in_hierarchy(
          hierarchy,
          fn n -> n.uuid === nested_page_one_node.uuid end
        )

      assert nested_node_parent.resource_id == unit_node.resource_id
    end

    test "find_and_remove_node/2", %{
      hierarchy: hierarchy,
      nested_page_one_node: nested_page_one_node
    } do
      assert Hierarchy.find_in_hierarchy(hierarchy, nested_page_one_node.uuid) != nil

      hierarchy =
        Hierarchy.find_and_remove_node(hierarchy, nested_page_one_node.uuid)
        |> Hierarchy.finalize()

      assert Hierarchy.find_in_hierarchy(hierarchy, nested_page_one_node.uuid) == nil
    end

    test "move_node/3", %{hierarchy: hierarchy, nested_page_one_node: nested_page_one_node} do
      node = Hierarchy.find_in_hierarchy(hierarchy, nested_page_one_node.uuid)

      hierarchy =
        Hierarchy.move_node(hierarchy, node, hierarchy.uuid)
        |> Hierarchy.finalize()

      assert Hierarchy.find_in_hierarchy(hierarchy, nested_page_one_node.uuid) != nil
      assert Enum.find(hierarchy.children, fn c -> c.uuid == node.uuid end) != nil
    end

    test "add_materials_to_hierarchy/4", %{
      hierarchy: hierarchy,
      unit_node: unit_node
    } do
      # create multiple other projects to add materials from
      %{pub2: p2_pub, page1: p2_page1} = Seeder.base_project_with_resource4()
      %{pub2: p3_pub, page1: p3_page1} = Seeder.base_project_with_resource4()

      selection = [{p2_pub.id, p2_page1.id}, {p3_pub.id, p3_page1.id}]

      publication_ids =
        selection
        |> Enum.reduce(%{}, fn {pub_id, _resource_id}, acc ->
          Map.put(acc, pub_id, true)
        end)
        |> Map.keys()

      published_resources_by_resource_id_by_pub =
        Publishing.get_published_resources_for_publications(publication_ids)

      hierarchy =
        Hierarchy.add_materials_to_hierarchy(
          hierarchy,
          unit_node,
          selection,
          published_resources_by_resource_id_by_pub
        )
        |> Hierarchy.finalize()

      assert hierarchy.children |> Enum.count() == 3
      assert hierarchy.children |> Enum.at(2) |> Map.get(:children) |> Enum.count() == 4

      assert hierarchy.children
             |> Enum.at(2)
             |> Map.get(:children)
             |> Enum.at(2)
             |> Map.get(:resource_id) == p2_page1.id

      assert hierarchy.children
             |> Enum.at(2)
             |> Map.get(:children)
             |> Enum.at(3)
             |> Map.get(:resource_id) == p3_page1.id
    end

    test "purge_duplicate_resources/1", %{
      hierarchy: hierarchy,
      unit_node: unit_node,
      page_one_node: page_one_node,
      page1: page1,
      nested_page1: nested_page1
    } do
      unit_node_with_duplicate_page_one = %HierarchyNode{
        unit_node
        | children: [page_one_node | unit_node.children]
      }

      hierarchy =
        Hierarchy.find_and_update_node(hierarchy, unit_node_with_duplicate_page_one)
        |> Hierarchy.finalize()

      assert hierarchy.children
             |> Enum.at(2)
             |> Map.get(:children)
             |> Enum.count() == 3

      assert hierarchy.children
             |> Enum.at(2)
             |> Map.get(:children)
             |> Enum.at(0)
             |> Map.get(:resource_id) == page1.id

      assert hierarchy.children
             |> Enum.at(2)
             |> Map.get(:children)
             |> Enum.at(1)
             |> Map.get(:resource_id) == nested_page1.id

      hierarchy =
        Hierarchy.purge_duplicate_resources(hierarchy)
        |> Hierarchy.finalize()

      assert hierarchy.children
             |> Enum.at(2)
             |> Map.get(:children)
             |> Enum.count() == 2

      assert hierarchy.children
             |> Enum.at(2)
             |> Map.get(:children)
             |> Enum.at(0)
             |> Map.get(:resource_id) == nested_page1.id
    end
  end

  describe "contained_scheduling_types/1" do
    setup [:create_elixir_project]

    test "returns the correct data per container id", %{
      section: section,
      root_container: root_container,
      unit_1: unit_1,
      unit_2: unit_2,
      module_1: module_1,
      section_1: section_1
    } do
      full_hierarchy = Hierarchy.full_hierarchy(section)

      scheduling_types =
        Hierarchy.contained_scheduling_types(full_hierarchy)

      assert Map.get(scheduling_types, root_container.resource_id) |> Enum.sort() == [
               :due_by,
               :inclass_activity,
               :read_by
             ]

      assert Map.get(scheduling_types, unit_1.resource_id) |> Enum.sort() == [
               :due_by,
               :read_by
             ]

      assert Map.get(scheduling_types, unit_2.resource_id) |> Enum.sort() == [
               :due_by,
               :read_by
             ]

      assert Map.get(scheduling_types, module_1.resource_id) |> Enum.sort() == [
               :due_by,
               :read_by
             ]

      assert Map.get(scheduling_types, section_1.resource_id) |> Enum.sort() == [
               :due_by
             ]
    end
  end

  describe "find_top_level_ancestor/3" do
    test "finds the top-level ancestor of a node in a simple hierarchy" do
      hierarchy = %{
        "resource_id" => "1",
        "name" => "Root Container",
        "children" => [
          %{"resource_id" => "2", "children" => [%{"resource_id" => "3"}]},
          %{"resource_id" => "4"}
        ]
      }

      # Ignores the Root Container
      assert Hierarchy.find_top_level_ancestor(hierarchy, "3") == %{
               "resource_id" => "2",
               "children" => [%{"resource_id" => "3"}]
             }
    end

    test "returns itself if it is a top level node" do
      hierarchy = %{
        "resource_id" => "1",
        "name" => "Root Container",
        "children" => [
          %{"resource_id" => "2", "children" => [%{"resource_id" => "3"}]},
          %{"resource_id" => "4"}
        ]
      }

      assert Hierarchy.find_top_level_ancestor(hierarchy, "2") == %{
               "resource_id" => "2",
               "children" => [%{"resource_id" => "3"}]
             }
    end

    test "returns nil if the resource_id is not found" do
      hierarchy = %{
        "resource_id" => "1",
        "children" => [
          %{"resource_id" => "2", "children" => [%{"resource_id" => "3"}]},
          %{"resource_id" => "4"}
        ]
      }

      refute Hierarchy.find_top_level_ancestor(hierarchy, "5")
    end

    test "returns the top-level ancestor when multiple levels deep" do
      hierarchy = %{
        "resource_id" => "1",
        "children" => [
          %{
            "resource_id" => "2",
            "children" => [
              %{"resource_id" => "3", "children" => [%{"resource_id" => "4"}]}
            ]
          }
        ]
      }

      assert Hierarchy.find_top_level_ancestor(hierarchy, "4") == %{
               "resource_id" => "2",
               "children" => [
                 %{"resource_id" => "3", "children" => [%{"resource_id" => "4"}]}
               ]
             }
    end
  end

  describe "thin_hierarchy/3" do
    test "retains only specified fields in a simple hierarchy" do
      hierarchy = %{
        "resource_id" => "1",
        "name" => "Root",
        "description" => "Root node",
        "children" => [
          %{"resource_id" => "2", "name" => "Child 1", "description" => "Child node 1"},
          %{"resource_id" => "3", "name" => "Child 2", "description" => "Child node 2"}
        ]
      }

      fields_to_keep = ["resource_id", "name", "children"]

      expected = %{
        "resource_id" => "1",
        "name" => "Root",
        "children" => [
          %{"resource_id" => "2", "name" => "Child 1"},
          %{"resource_id" => "3", "name" => "Child 2"}
        ]
      }

      assert Hierarchy.thin_hierarchy(hierarchy, fields_to_keep) == expected
    end

    test "filters out nodes based on a custom filter function" do
      hierarchy = %{
        "resource_id" => "1",
        "name" => "Root",
        "children" => [
          %{"resource_id" => "2", "name" => "Child 1"},
          %{"resource_id" => "3", "name" => "Child 2"}
        ]
      }

      fields_to_keep = ["resource_id", "name", "children"]
      filter_fn = fn node -> node["resource_id"] != "2" end

      expected = %{
        "resource_id" => "1",
        "name" => "Root",
        "children" => [
          %{"resource_id" => "3", "name" => "Child 2"}
        ]
      }

      assert Hierarchy.thin_hierarchy(hierarchy, fields_to_keep, filter_fn) == expected
    end

    test "returns nil if the root node does not satisfy the filter function" do
      hierarchy = %{
        "resource_id" => "1",
        "name" => "Root",
        "description" => "Root node",
        "children" => [
          %{"resource_id" => "2", "name" => "Child 1"},
          %{"resource_id" => "3", "name" => "Child 2"}
        ]
      }

      fields_to_keep = ["resource_id", "name"]
      filter_fn = fn node -> node["resource_id"] != "1" end

      assert Hierarchy.thin_hierarchy(hierarchy, fields_to_keep, filter_fn) == nil
    end

    test "handles a list of nodes as the root of the hierarchy" do
      hierarchy = [
        %{
          "resource_id" => "1",
          "name" => "Node 1",
          "children" => [%{"resource_id" => "2", "name" => "Child 1"}]
        },
        %{
          "resource_id" => "3",
          "name" => "Node 2",
          "children" => [%{"resource_id" => "4", "name" => "Child 2"}]
        }
      ]

      fields_to_keep = ["name", "children"]

      expected = [
        %{
          "name" => "Node 1",
          "children" => [%{"name" => "Child 1"}]
        },
        %{
          "name" => "Node 2",
          "children" => [%{"name" => "Child 2"}]
        }
      ]

      assert Hierarchy.thin_hierarchy(hierarchy, fields_to_keep) == expected
    end

    test "returns an empty list if all nodes are filtered out" do
      hierarchy = [
        %{"resource_id" => "1", "name" => "Node 1"},
        %{"resource_id" => "2", "name" => "Node 2"}
      ]

      fields_to_keep = ["resource_id", "name"]
      filter_fn = fn _ -> false end

      assert Hierarchy.thin_hierarchy(hierarchy, fields_to_keep, filter_fn) == []
    end

    test "handles an empty hierarchy gracefully" do
      hierarchy = %{}
      fields_to_keep = ["resource_id", "name"]

      assert Hierarchy.thin_hierarchy(hierarchy, fields_to_keep) == %{}
    end

    test "handles an empty list of nodes gracefully" do
      hierarchy = []
      fields_to_keep = ["resource_id", "name"]

      assert Hierarchy.thin_hierarchy(hierarchy, fields_to_keep) == []
    end
  end

  describe "filter_hierarchy_by_search_term/2" do
    setup do
      hierarchy = %{
        "children" => [
          %{
            "children" => [
              %{
                "children" => [
                  %{
                    "children" => [],
                    "resource_type_id" => 1,
                    "title" => "Enum.map/2"
                  },
                  %{
                    "children" => [],
                    "resource_type_id" => 1,
                    "title" => "Enum.filter/2"
                  }
                ],
                "resource_type_id" => 2,
                "title" => "Enum module"
              }
            ],
            "resource_type_id" => 2,
            "title" => "Introduction"
          },
          %{
            "children" => [
              %{
                "children" => [
                  %{"children" => [], "resource_type_id" => 1, "title" => "Map.get/2"}
                ],
                "resource_type_id" => 2,
                "title" => "Map module"
              },
              %{
                "children" => [
                  %{"children" => [], "resource_type_id" => 1, "title" => "another page"}
                ],
                "resource_type_id" => 2,
                "title" => "Another module"
              }
            ],
            "resource_type_id" => 2,
            "title" => "Basics"
          }
        ],
        "title" => "Root"
      }

      %{hierarchy: hierarchy}
    end

    test "returns unchanged hierarchy when search term is empty string", %{hierarchy: hierarchy} do
      result = Hierarchy.filter_hierarchy_by_search_term(hierarchy, "")
      assert result == hierarchy
    end

    test "returns unchanged hierarchy when search term is nil", %{hierarchy: hierarchy} do
      result = Hierarchy.filter_hierarchy_by_search_term(hierarchy, nil)
      assert result == hierarchy
    end

    test "filters hierarchy when searching for a container title", %{hierarchy: hierarchy} do
      result = Hierarchy.filter_hierarchy_by_search_term(hierarchy, "another module")
      [unit] = result["children"]
      [module] = unit["children"]

      assert result["child_matches_search_term"]
      assert length(result["children"]) == 1

      assert unit["title"] == "Basics"
      assert unit["child_matches_search_term"]
      assert unit["children"] |> length() == 1

      assert module["title"] == "Another module"
      refute module["child_matches_search_term"]
      assert module["children"] |> length() == 1
    end

    test "filters hierarchy when searching for a page title", %{hierarchy: hierarchy} do
      result = Hierarchy.filter_hierarchy_by_search_term(hierarchy, "enum.filter/2")
      [unit] = result["children"]
      [module] = unit["children"]
      [page] = module["children"]

      assert result["child_matches_search_term"]
      assert length(result["children"]) == 1

      assert unit["title"] == "Introduction"
      assert unit["child_matches_search_term"]
      assert unit["children"] |> length() == 1

      assert module["title"] == "Enum module"
      assert module["child_matches_search_term"]
      assert module["children"] |> length() == 1

      assert page["title"] == "Enum.filter/2"
      refute page["child_matches_search_term"]
      assert page["children"] == []
    end

    test "filters hierarchy when searching for a partial match", %{hierarchy: hierarchy} do
      result = Hierarchy.filter_hierarchy_by_search_term(hierarchy, "enum")
      [unit] = result["children"]
      [module] = unit["children"]
      [page_1, page_2] = module["children"]

      assert result["child_matches_search_term"]
      assert length(result["children"]) == 1

      assert unit["title"] == "Introduction"
      assert unit["child_matches_search_term"]
      assert unit["children"] |> length() == 1

      assert module["title"] == "Enum module"
      assert module["child_matches_search_term"]
      assert module["children"] |> length() == 2

      assert page_1["title"] == "Enum.map/2"
      refute page_1["child_matches_search_term"]
      assert page_1["children"] == []

      assert page_2["title"] == "Enum.filter/2"
      refute page_2["child_matches_search_term"]
      assert page_2["children"] == []
    end

    test "filters hierarchy when searching is case insensitive", %{hierarchy: hierarchy} do
      result = Hierarchy.filter_hierarchy_by_search_term(hierarchy, "ENUM")
      [unit] = result["children"]
      [module] = unit["children"]
      [page_1, page_2] = module["children"]

      assert result["child_matches_search_term"]
      assert length(result["children"]) == 1

      assert unit["title"] == "Introduction"
      assert unit["child_matches_search_term"]
      assert unit["children"] |> length() == 1

      assert module["title"] == "Enum module"
      assert module["child_matches_search_term"]
      assert module["children"] |> length() == 2

      assert page_1["title"] == "Enum.map/2"
      refute page_1["child_matches_search_term"]
      assert page_1["children"] == []

      assert page_2["title"] == "Enum.filter/2"
      refute page_2["child_matches_search_term"]
      assert page_2["children"] == []
    end
  end

  defp create_elixir_project(_) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    #  Root Container:
    #       |_ Page 1 (scheduling_type = :inclass_activity)
    #       |_ Unit 1:
    #         |_ Page 2 (scheduling_type = :due_by)
    #         |_ Page 3 (scheduling_type = :read_by)
    #       |_ Unit 2:
    #         |_ Module 1:
    #           |_ Page 4 (scheduling_type = :read_by)
    #           |_ Page 5 (scheduling_type = :read_by)
    #           |_ Section 1:
    #             |_ Page 6 (scheduling_type = :due_by)
    #             |_ Page 7 (scheduling_type = :due_by)

    # revisions...

    ## pages...
    page_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 1"
      )

    page_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 2"
      )

    page_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 3"
      )

    page_4_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 4"
      )

    page_5_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 5"
      )

    page_6_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 6"
      )

    page_7_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 7"
      )

    ## modules...

    section_1_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.get_id_by_type("container"),
        children: [page_6_revision.resource_id, page_7_revision.resource_id],
        title: "Section 1"
      })

    module_1_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.get_id_by_type("container"),
        children: [
          section_1_revision.resource_id,
          page_4_revision.resource_id,
          page_5_revision.resource_id
        ],
        title: "How to use this course"
      })

    ## units...
    unit_1_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.get_id_by_type("container"),
        children: [page_2_revision.resource_id, page_3_revision.resource_id],
        title: "Introduction"
      })

    unit_2_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.get_id_by_type("container"),
        children: [module_1_revision.resource_id],
        title: "OTP"
      })

    ## root container...
    root_container_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.get_id_by_type("container"),
        children: [
          page_1_revision.resource_id,
          unit_1_revision.resource_id,
          unit_2_revision.resource_id
        ],
        title: "Root Container"
      })

    all_revisions =
      [
        page_1_revision,
        page_2_revision,
        page_3_revision,
        page_4_revision,
        page_5_revision,
        page_6_revision,
        page_7_revision,
        section_1_revision,
        module_1_revision,
        unit_1_revision,
        unit_2_revision,
        root_container_revision
      ]

    # asociate resources to project
    Enum.each(all_revisions, fn revision ->
      insert(:project_resource, %{
        project_id: project.id,
        resource_id: revision.resource_id
      })
    end)

    # publish project
    publication =
      insert(:publication, %{
        project: project,
        root_resource_id: root_container_revision.resource_id
      })

    # publish resources
    Enum.each(all_revisions, fn revision ->
      insert(:published_resource, %{
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: author
      })
    end)

    # create section...
    section =
      insert(:section,
        base_project: project,
        title: "The best course ever!",
        start_date: ~U[2023-10-30 20:00:00Z],
        analytics_version: :v2
      )

    {:ok, section} = Sections.create_section_resources(section, publication)

    # update page's scheduling types
    Sections.get_section_resource(section.id, page_1_revision.resource_id)
    |> Sections.update_section_resource(%{scheduling_type: :inclass_activity})

    Sections.get_section_resource(section.id, page_2_revision.resource_id)
    |> Sections.update_section_resource(%{scheduling_type: :due_by})

    Sections.get_section_resource(section.id, page_6_revision.resource_id)
    |> Sections.update_section_resource(%{scheduling_type: :due_by})

    Sections.get_section_resource(section.id, page_7_revision.resource_id)
    |> Sections.update_section_resource(%{scheduling_type: :due_by})

    %{
      author: author,
      section: section,
      project: project,
      publication: publication,
      page_1: page_1_revision,
      page_2: page_2_revision,
      page_3: page_3_revision,
      page_4: page_4_revision,
      page_5: page_4_revision,
      page_6: page_4_revision,
      page_7: page_4_revision,
      section_1: section_1_revision,
      module_1: module_1_revision,
      unit_1: unit_1_revision,
      unit_2: unit_2_revision,
      root_container: root_container_revision
    }
  end
end
