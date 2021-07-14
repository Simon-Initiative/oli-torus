defmodule Oli.Publishing.AuthoringResolverTest do
  use Oli.DataCase

  alias Oli.Publishing.AuthoringResolver

  describe "authoring resolution" do
    setup do
      Seeder.base_project_with_resource4()
    end

    test "find_parent_objectives/2 returns parents", %{
      project: project,
      child1: child1,
      child2: child2,
      child3: child3,
      child4: child4,
      parent1: parent1,
      parent2: parent2
    } do
      # find one
      assert [parent1.revision] ==
               AuthoringResolver.find_parent_objectives(project.slug, [child1.resource.id])

      # find both
      assert [parent1.revision, parent2.revision] ==
               AuthoringResolver.find_parent_objectives(project.slug, [
                 child1.resource.id,
                 child4.resource.id
               ])

      assert [parent1.revision, parent2.revision] ==
               AuthoringResolver.find_parent_objectives(project.slug, [
                 child1.resource.id,
                 child2.resource.id,
                 child3.resource.id,
                 child4.resource.id
               ])

      # find none
      assert [] ==
               AuthoringResolver.find_parent_objectives(project.slug, [
                 parent1.resource.id,
                 parent2.resource.id
               ])
    end

    test "from_resource_id/2 returns correct revision", %{
      revision1: revision,
      latest1: latest1,
      project: project
    } do
      r = AuthoringResolver.from_resource_id(project.slug, revision.resource_id)
      assert r.id == latest1.id

      # verifies we return nil on a made up id
      assert AuthoringResolver.from_resource_id(project.slug, 1337) == nil
    end

    test "from_revision_slug/2 returns correct revision", %{
      revision1: revision1,
      latest1: latest1,
      project: project
    } do
      # verifies we can resolve a historical slug
      r = AuthoringResolver.from_revision_slug(project.slug, revision1.slug)

      assert r.id == latest1.id

      # verifies we can resolve the current slug
      assert AuthoringResolver.from_revision_slug(project.slug, latest1.slug) == latest1

      # verifies we return nil on a made up slug
      assert AuthoringResolver.from_revision_slug(project.slug, "does_not_exist") == nil
    end

    test "from_resource_id/2 returns correct list of revisions", %{
      latest1: latest1,
      latest2: latest2,
      revision2: revision2,
      revision1: revision1,
      project: project
    } do
      r =
        AuthoringResolver.from_resource_id(project.slug, [
          revision1.resource_id,
          revision2.resource_id
        ])

      assert length(r) == 2
      assert Enum.at(r, 0) == latest1
      assert Enum.at(r, 1) == latest2
    end

    test "from_resource_id/2 orders results according to inputs", %{
      latest1: latest1,
      latest2: latest2,
      revision2: revision2,
      revision1: revision1,
      project: project
    } do
      r =
        AuthoringResolver.from_resource_id(project.slug, [
          revision2.resource_id,
          revision1.resource_id
        ])

      assert length(r) == 2
      assert Enum.at(r, 0) == latest2
      assert Enum.at(r, 1) == latest1
    end

    test "from_resource_id/2 inserts nils where some are missing", %{
      latest2: latest2,
      revision2: revision2,
      project: project
    } do
      r = AuthoringResolver.from_resource_id(project.slug, [revision2.resource_id, 1337])

      assert length(r) == 2
      assert Enum.at(r, 0) == latest2
      assert Enum.at(r, 1) == nil
    end

    test "all_revisions/1 resolves the all revisions", %{project: project} do
      nodes = AuthoringResolver.all_revisions(project.slug)
      assert length(nodes) == 18
    end

    test "all_revisions_in_hierarchy/1 resolves all revisions in the hierarchy", %{
      project: project
    } do
      nodes = AuthoringResolver.all_revisions_in_hierarchy(project.slug)
      assert length(nodes) == 8
    end

    test "root_resource/1 resolves the root revision", %{
      container: %{revision: container_revision},
      project: project
    } do
      assert AuthoringResolver.root_container(project.slug) == container_revision
      assert AuthoringResolver.root_container("invalid") == nil
    end

    test "full_hierarchy/1 resolves and reconstructs the entire hierarchy", %{
      project: project
    } do
      hierarchy = AuthoringResolver.full_hierarchy(project.slug)

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
