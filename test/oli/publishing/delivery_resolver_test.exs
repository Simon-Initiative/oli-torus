defmodule Oli.Publishing.DeliveryResolverTest do
  use Oli.DataCase

  alias Oli.Publishing.DeliveryResolver

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

    test "all_revisions/1 resolves the all revisions", %{} do
      nodes = DeliveryResolver.all_revisions("1")
      assert length(nodes) == 9
    end

    test "all_revisions_in_hierarchy/1 resolves all revisions in the hierarchy", %{} do
      nodes = DeliveryResolver.all_revisions_in_hierarchy("1")
      assert length(nodes) == 3
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

      assert hierarchy.numbering_index == 1
      assert hierarchy.numbering_level == 0
      assert Enum.count(hierarchy.children) == 3
      assert hierarchy.children |> Enum.at(0) |> Map.get(:numbering_index) == 1
      assert hierarchy.children |> Enum.at(0) |> Map.get(:numbering_level) == 1

      assert hierarchy.children |> Enum.at(1) |> Map.get(:numbering_index) == 2
      assert hierarchy.children |> Enum.at(2) |> Map.get(:numbering_index) == 3

      assert hierarchy.children
             |> Enum.at(2)
             |> Map.get(:children)
             |> Enum.at(0)
             |> Map.get(:numbering_index) == 1

      assert hierarchy.children
             |> Enum.at(2)
             |> Map.get(:children)
             |> Enum.at(0)
             |> Map.get(:numbering_level) == 2
    end
  end
end
