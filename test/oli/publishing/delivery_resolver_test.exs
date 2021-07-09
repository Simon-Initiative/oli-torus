defmodule Oli.Publishing.DeliveryResolverTest do
  use Oli.DataCase

  alias Oli.Publishing.DeliveryResolver
  alias Oli.Publishing
  alias Oli.Delivery.Sections

  describe "delivery resolution" do
    setup do
      map =
        Seeder.base_project_with_resource2()
        |> Seeder.add_objective("child1", :child1)
        |> Seeder.add_objective("child2", :child2)
        |> Seeder.add_objective("child3", :child3)
        |> Seeder.add_objective("child4", :child4)
        |> Seeder.add_objective_with_children("parent1", [:child1, :child2, :child3], :parent1)
        |> Seeder.add_objective_with_children("parent2", [:child4], :parent2)

      # Create another project with resources and revisions
      Seeder.another_project(map.author, map.institution)

      # Publish the current state of our test project:
      {:ok, pub1} = Publishing.publish_project(map.project)

      # Track a series of changes for both resources:
      pub = Publishing.working_project_publication(map.project.slug)

      latest1 =
        Publishing.publish_new_revision(map.revision1, %{title: "1"}, pub, map.author.id)
        |> Publishing.publish_new_revision(%{title: "2"}, pub, map.author.id)
        |> Publishing.publish_new_revision(%{title: "3"}, pub, map.author.id)
        |> Publishing.publish_new_revision(%{title: "4"}, pub, map.author.id)

      latest2 =
        Publishing.publish_new_revision(map.revision2, %{title: "A"}, pub, map.author.id)
        |> Publishing.publish_new_revision(%{title: "B"}, pub, map.author.id)
        |> Publishing.publish_new_revision(%{title: "C"}, pub, map.author.id)
        |> Publishing.publish_new_revision(%{title: "D"}, pub, map.author.id)

      # Create a new page that wasn't present during the first publication
      %{revision: latest3} = Seeder.create_page("New To Pub2", pub, map.project, map.author)

      second_map = Seeder.add_objective(Map.merge(map, %{publication: pub}), "child5", :child5)

      second_map =
        Seeder.add_objective_with_children(
          Map.merge(second_map, %{publication: pub}),
          "parent3",
          [:child5],
          :parent3
        )

      # Publish again
      {:ok, pub2} = Publishing.publish_project(map.project)

      # Create a fourth page that is completely unpublished
      pub = Publishing.working_project_publication(map.project.slug)
      %{revision: latest4} = Seeder.create_page("Unpublished", pub, map.project, map.author)

      third_map = Seeder.add_objective(Map.merge(map, %{publication: pub}), "child6", :child6)

      third_map =
        Seeder.add_objective_with_children(
          Map.merge(third_map, %{publication: pub}),
          "parent4",
          [:child6],
          :parent4
        )

      # Create a course section, one for each publication
      {:ok, section_1} =
        Sections.create_section(%{
          title: "1",
          timezone: "1",
          registration_open: true,
          context_id: "1",
          institution_id: map.institution.id,
          base_project_id: map.project.id
        })
        |> then(fn {:ok, section} -> section end)
        |> Sections.create_section_resources(pub1)

      {:ok, section_2} =
        Sections.create_section(%{
          title: "2",
          timezone: "1",
          registration_open: true,
          context_id: "2",
          institution_id: map.institution.id,
          base_project_id: map.project.id
        })
        |> then(fn {:ok, section} -> section end)
        |> Sections.create_section_resources(pub2)

      Map.put(map, :latest1, latest1)
      |> Map.put(:latest2, latest2)
      |> Map.put(:pub1, pub1)
      |> Map.put(:pub2, pub2)
      |> Map.put(:latest3, latest3)
      |> Map.put(:latest4, latest4)
      |> Map.put(:child5, Map.get(second_map, :child5))
      |> Map.put(:parent3, Map.get(second_map, :parent3))
      |> Map.put(:child6, Map.get(third_map, :child6))
      |> Map.put(:parent4, Map.get(third_map, :parent4))
      |> Map.put(:section_1, section_1)
      |> Map.put(:section_2, section_2)
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
      assert DeliveryResolver.from_resource_id("1", 1337) == nil
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

    test "all_revisions/1 resolves the all nodes", %{} do
      nodes = DeliveryResolver.all_revisions("1")
      assert length(nodes) == 9
    end

    test "all_revisions_in_hierarchy/1 resolves the all hierarchy nodes", %{} do
      nodes = DeliveryResolver.all_revisions_in_hierarchy("1")
      assert length(nodes) == 3
    end

    test "root_resource/1 resolves the root revision", %{
      container: %{revision: container_revision}
    } do
      assert DeliveryResolver.root_container("1") == container_revision
      assert DeliveryResolver.root_container("2") == container_revision
    end
  end
end
