defmodule Oli.Publishing.AuthoringResolverTest do
  use Oli.DataCase

  alias Oli.Publishing.AuthoringResolver
  alias Oli.Publishing

  describe "authoring resolution" do

    setup do

      map = Seeder.base_project_with_resource2()

      # Create another project with resources and revisions
      Seeder.another_project(map.author, map.institution)

      # Publish the current state of our test project:
      Publishing.publish_project(map.project)

      # Track a series of changes for both resources:
      pub = Publishing.get_unpublished_publication_by_slug!(map.project.slug)

      latest1 = Publishing.publish_new_revision(map.revision1, %{ title: "1"}, pub, map.author.id)
      |> Publishing.publish_new_revision(%{ title: "2"}, pub, map.author.id)
      |> Publishing.publish_new_revision(%{ title: "3"}, pub, map.author.id)
      |> Publishing.publish_new_revision(%{ title: "4"}, pub, map.author.id)

      latest2 = Publishing.publish_new_revision(map.revision2, %{ title: "A"}, pub, map.author.id)
      |> Publishing.publish_new_revision(%{ title: "B"}, pub, map.author.id)
      |> Publishing.publish_new_revision(%{ title: "C"}, pub, map.author.id)
      |> Publishing.publish_new_revision(%{ title: "D"}, pub, map.author.id)

      Map.put(map, :latest1, latest1)
      |> Map.put(:latest2, latest2)
    end

    test "from_resource_id/2 returns correct revision", %{ revision1: revision, latest1: latest1, project: project } do

      r = AuthoringResolver.from_resource_id(project.slug, revision.resource_id)
      assert r.id == latest1.id

      # verifies we return nil on a made up id
      assert AuthoringResolver.from_resource_id(project.slug, 1337) == nil

    end

    test "from_revision_slug/2 returns correct revision", %{ revision1: revision1, latest1: latest1, project: project } do

      # verifies we can resolve a historical slug
      r = AuthoringResolver.from_revision_slug(project.slug, revision1.slug)


      assert r.id == latest1.id

      # verifies we can resolve the current slug
      assert AuthoringResolver.from_revision_slug(project.slug, latest1.slug) == latest1

      # verifies we return nil on a made up slug
      assert AuthoringResolver.from_revision_slug(project.slug, "does_not_exist") == nil


    end


    test "from_resource_id/2 returns correct list of revisions", %{ latest1: latest1, latest2: latest2, revision2: revision2, revision1: revision1, project: project } do

      r = AuthoringResolver.from_resource_id(project.slug, [revision1.resource_id, revision2.resource_id])

      assert length(r) == 2
      assert Enum.at(r, 0) == latest1
      assert Enum.at(r, 1) == latest2

    end

    test "from_resource_id/2 orders results according to inputs", %{ latest1: latest1, latest2: latest2, revision2: revision2, revision1: revision1, project: project } do

      r = AuthoringResolver.from_resource_id(project.slug, [revision2.resource_id, revision1.resource_id])

      assert length(r) == 2
      assert Enum.at(r, 0) == latest2
      assert Enum.at(r, 1) == latest1

    end

    test "from_resource_id/2 inserts nils where some are missing", %{ latest2: latest2, revision2: revision2, project: project } do

      r = AuthoringResolver.from_resource_id(project.slug, [revision2.resource_id, 1337])

      assert length(r) == 2
      assert Enum.at(r, 0) == latest2
      assert Enum.at(r, 1) == nil

    end

    test "publication/1 doesn't retrieve the already published publication", %{ publication: publication, project: project } do

      refute AuthoringResolver.publication(project.slug) == publication
      assert AuthoringResolver.publication("invalid") == nil

    end

    test "root_resource/1 resolves the root revision", %{ container_revision: container_revision, project: project } do

      assert AuthoringResolver.root_resource(project.slug) == container_revision
      assert AuthoringResolver.root_resource("invalid") == nil

    end


  end

end
