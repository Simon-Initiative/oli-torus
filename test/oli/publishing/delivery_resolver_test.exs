defmodule Oli.Publishing.DeliveryResolverTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.ResourceType
  alias Oli.Delivery.Sections

  describe "delivery resolution" do
    setup do
      Seeder.base_project_with_resource4()
    end

    test "find_parent_objectives/2 returns parents", %{
      child1: child1,
      child2: child2,
      child3: child3,
      child4: child4,
      parent1: parent1,
      parent2: parent2,
      child5: child5,
      parent3: parent3,
      child6: child6
    } do
      # find one
      assert [parent1.revision] ==
               DeliveryResolver.find_parent_objectives("1", [child1.resource.id])

      # find both
      assert [parent1.revision, parent2.revision] ==
               DeliveryResolver.find_parent_objectives("1", [
                 child1.resource.id,
                 child4.resource.id
               ])

      assert [parent1.revision, parent2.revision] ==
               DeliveryResolver.find_parent_objectives("1", [
                 child1.resource.id,
                 child2.resource.id,
                 child3.resource.id,
                 child4.resource.id
               ])

      # find none
      assert [] ==
               DeliveryResolver.find_parent_objectives("1", [
                 parent1.resource.id,
                 parent2.resource.id
               ])

      # child5 should only resolve in section 2
      assert [] == DeliveryResolver.find_parent_objectives("1", [child5.resource.id])

      assert [parent3.revision] ==
               DeliveryResolver.find_parent_objectives("2", [child5.resource.id])

      # child6 should not resolve anywhere since it and its parent are unpublished
      assert [] == DeliveryResolver.find_parent_objectives("1", [child6.resource.id])
      assert [] == DeliveryResolver.find_parent_objectives("2", [child6.resource.id])
    end

    test "from_resource_id/2 returns correct revision", %{
      revision1: revision1,
      latest1: latest1,
      latest4: latest4
    } do
      assert DeliveryResolver.from_resource_id("1", revision1.resource_id).id == revision1.id
      assert DeliveryResolver.from_resource_id("2", revision1.resource_id).id == latest1.id

      assert DeliveryResolver.from_resource_id("1", latest4.resource_id) == nil
      assert DeliveryResolver.from_resource_id("2", latest4.resource_id) == nil

      # verifies we return nil on a made up id
      non_existent_resource_id = latest_record_index("resources") + 1
      assert DeliveryResolver.from_resource_id("1", non_existent_resource_id) == nil
    end

    test "from_revision_slug/2 returns correct revision", %{
      revision1: revision1,
      latest1: latest1,
      latest4: latest4
    } do
      assert DeliveryResolver.from_revision_slug("1", revision1.slug).id == revision1.id
      assert DeliveryResolver.from_revision_slug("2", revision1.slug).id == latest1.id

      # resolve an intermediate revision
      assert DeliveryResolver.from_revision_slug("2", "3").id == latest1.id

      # resolve nil on the one that was never published
      assert DeliveryResolver.from_revision_slug("1", latest4.slug) == nil
      assert DeliveryResolver.from_revision_slug("2", latest4.slug) == nil

      # verifies we return nil on a made up slug
      assert DeliveryResolver.from_revision_slug("1", "made_up") == nil
    end

    test "from_resource_id/2 returns correct list of revisions", %{
      latest1: latest1,
      latest2: latest2,
      revision2: revision2,
      revision1: revision1,
      latest4: latest4,
      section_1: section_1,
      section_2: section_2
    } do
      assert DeliveryResolver.from_resource_id(section_1.slug, [
               revision1.resource_id,
               revision2.resource_id
             ]) ==
               [revision1, revision2]

      assert DeliveryResolver.from_resource_id(section_2.slug, [
               revision1.resource_id,
               revision2.resource_id
             ]) ==
               [latest1, latest2]

      assert DeliveryResolver.from_resource_id(section_1.slug, [
               latest4.resource_id,
               revision2.resource_id
             ]) ==
               [nil, revision2]

      assert DeliveryResolver.from_resource_id(section_2.slug, [
               latest4.resource_id,
               revision2.resource_id
             ]) ==
               [nil, latest2]

      # verifies we return nil on a made up id
      assert DeliveryResolver.from_resource_id("1", [133_799, 18_283_823]) == [nil, nil]
    end

    test "from_resource_id/2 orders results according to inputs", %{
      latest1: latest1,
      latest2: latest2,
      revision2: revision2,
      revision1: revision1,
      latest4: latest4
    } do
      assert DeliveryResolver.from_resource_id("1", [revision2.resource_id, revision1.resource_id]) ==
               [revision2, revision1]

      assert DeliveryResolver.from_resource_id("2", [revision2.resource_id, revision1.resource_id]) ==
               [latest2, latest1]

      assert DeliveryResolver.from_resource_id("1", [revision2.resource_id, latest4.resource_id]) ==
               [revision2, nil]

      assert DeliveryResolver.from_resource_id("2", [revision2.resource_id, latest4.resource_id]) ==
               [latest2, nil]
    end

    test "all_revisions/1 resolves the all revisions", %{} do
      nodes = DeliveryResolver.all_revisions("1")
      assert length(nodes) == 12
    end

    test "all_revisions_in_hierarchy/1 resolves all revisions in the hierarchy", %{} do
      nodes = DeliveryResolver.all_revisions_in_hierarchy("1")
      assert length(nodes) == 6
    end

    test "root_resource/1 resolves the root revision", %{
      container: %{revision: container_revision}
    } do
      assert DeliveryResolver.root_container("1") == container_revision
      assert DeliveryResolver.root_container("2") == container_revision
    end

    test "full_hierarchy/1 resolves and reconstructs the entire hierarchy", %{
      section_1: section
    } do
      hierarchy = DeliveryResolver.full_hierarchy(section.slug)

      assert hierarchy.numbering.index == 1
      assert hierarchy.numbering.level == 0
      assert Enum.count(hierarchy.children) == 3
      assert hierarchy.children |> Enum.at(0) |> Map.get(:numbering) |> Map.get(:index) == 1
      assert hierarchy.children |> Enum.at(0) |> Map.get(:numbering) |> Map.get(:level) == 1

      assert hierarchy.children |> Enum.at(1) |> Map.get(:numbering) |> Map.get(:index) == 2
      assert hierarchy.children |> Enum.at(2) |> Map.get(:numbering) |> Map.get(:index) == 1

      assert hierarchy.children
             |> Enum.at(2)
             |> Map.get(:children)
             |> Enum.at(0)
             |> Map.get(:numbering)
             |> Map.get(:index) == 3

      assert hierarchy.children
             |> Enum.at(2)
             |> Map.get(:children)
             |> Enum.at(0)
             |> Map.get(:numbering)
             |> Map.get(:level) == 2
    end

    test "revisions_of_type/2 returns all revisions of a specified type", %{
      section_1: section
    } do
      revisions =
        DeliveryResolver.revisions_of_type(
          section.slug,
          ResourceType.id_for_page()
        )

      assert Enum.count(revisions) == 4

      assert revisions |> Enum.map(& &1.title) |> Enum.sort() == [
               "Nested Page One",
               "Nested Page Two",
               "Page one",
               "Page two"
             ]
    end

    test "get_by_purpose/2 returns all revisions when receive a valid section_slug and purpose",
         %{} do
      {:ok,
       project: _project,
       section: section,
       page_revision: page_revision,
       other_revision: other_revision} = project_section_revisions(%{})

      assert section.slug
             |> DeliveryResolver.get_by_purpose(page_revision.purpose)
             |> length() == 1

      assert section.slug
             |> DeliveryResolver.get_by_purpose(other_revision.purpose)
             |> length() == 1
    end

    test "get_by_purpose/2 returns empty list when receive a invalid section_slug",
         %{} do
      section = insert(:section)

      assert DeliveryResolver.get_by_purpose(section.slug, :foundation) == []
      assert DeliveryResolver.get_by_purpose(section.slug, :application) == []
    end

    test "targeted_via_related_to/2 returns all revisions when receive a valid section_slug and resource_id",
         %{} do
      {:ok,
       project: _project,
       section: section,
       page_revision: page_revision,
       other_revision: _other_revision} = project_section_revisions(%{})

      assert section.slug
             |> DeliveryResolver.targeted_via_related_to(page_revision.resource_id)
             |> length() == 1
    end

    test "targeted_via_related_to/2 returns empty list when don't receive a valid section_slug and resource_id",
         %{} do
      section = insert(:section)

      page_revision =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          title: "Example test revision",
          graded: true,
          content: %{"advancedDelivery" => true}
        )

      assert DeliveryResolver.targeted_via_related_to(section.slug, page_revision.resource_id) ==
               []
    end
  end

  describe "graded_pages_revisions_and_section_resources/1" do
    setup [:create_elixir_project]

    test "returns graded pages in order", %{
      section: section
    } do
      pages = DeliveryResolver.graded_pages_revisions_and_section_resources(section.slug)

      assert length(pages) == 3

      assert Enum.map(pages, fn {rev, _} -> rev.title end) == [
               "Page 1",
               "Page 2",
               "Page 4"
             ]
    end
  end

  defp create_elixir_project(_) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # revisions...

    ## pages...
    page_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 1",
        graded: true
      )

    page_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 2",
        graded: true
      )

    page_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 3"
      )

    page_4_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 4",
        graded: true
      )

    ## modules...
    module_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [
          page_1_revision.resource_id,
          page_2_revision.resource_id
        ],
        title: "Module 1"
      })

    module_2_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_3_revision.resource_id],
        title: "Module 2"
      })

    ## units...
    unit_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [
          module_1_revision.resource_id,
          module_2_revision.resource_id,
          page_4_revision.resource_id
        ],
        title: "Unit 1"
      })

    ## root container...
    container_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [
          unit_1_revision.resource_id
        ],
        title: "Root Container"
      })

    all_revisions =
      [
        page_1_revision,
        page_2_revision,
        page_3_revision,
        page_4_revision,
        module_1_revision,
        module_2_revision,
        unit_1_revision,
        container_revision
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
      insert(:publication, %{project: project, root_resource_id: container_revision.resource_id})

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
    {:ok, _} = Sections.rebuild_contained_pages(section)
    {:ok, _} = Sections.rebuild_contained_objectives(section)

    %{
      author: author,
      section: section,
      project: project,
      publication: publication,
      page_1: page_1_revision,
      page_2: page_2_revision,
      page_3: page_3_revision,
      page_4: page_4_revision,
      module_1: module_1_revision,
      module_2: module_2_revision,
      unit_1: unit_1_revision
    }
  end
end
