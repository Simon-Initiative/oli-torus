defmodule Oli.Publishing.DeliveryResolverTest do
  use Oli.DataCase

  alias Oli.Publishing.DeliveryResolver
  alias Oli.Publishing
  alias Oli.Delivery.Sections

  describe "delivery resolution" do

    setup do

      map = Seeder.base_project_with_resource2()

      # Create another project with resources and revisions
      Seeder.another_project(map.author, map.institution)

      # Publish the current state of our test project:
      {:ok, pub1} = Publishing.publish_project(map.project)

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

      # Create a new page that wasn't present during the first publication
      %{revision: latest3 } = Seeder.create_page("New To Pub2", pub, map.project, map.author)

      # Publish again
      {:ok, pub2} = Publishing.publish_project(map.project)

      # Create a fourth page that is completely unpublished
      pub = Publishing.get_unpublished_publication_by_slug!(map.project.slug)
      %{revision: latest4 } = Seeder.create_page("Unpublished", pub, map.project, map.author)

      # Create a course section, one for each publication
      {:ok, _} = Sections.create_section(%{title: "1", time_zone: "1", registration_open: true, context_id: "1",
        institution_id: map.institution.id, project_id: map.project.id, publication_id: pub1.id })
      {:ok, _} = Sections.create_section(%{title: "2", time_zone: "1", registration_open: true, context_id: "2",
        institution_id: map.institution.id, project_id: map.project.id, publication_id: pub2.id })

      Map.put(map, :latest1, latest1)
      |> Map.put(:latest2, latest2)
      |> Map.put(:pub1, pub1)
      |> Map.put(:pub2, pub2)
      |> Map.put(:latest3, latest3)
      |> Map.put(:latest4, latest4)
    end

    test "from_resource_id/2 returns correct revision", %{ revision1: revision1, latest1: latest1, latest4: latest4 } do

      assert DeliveryResolver.from_resource_id("1", revision1.resource_id).id == revision1.id
      assert DeliveryResolver.from_resource_id("2", revision1.resource_id).id == latest1.id

      assert DeliveryResolver.from_resource_id("1", latest4.resource_id) == nil
      assert DeliveryResolver.from_resource_id("2", latest4.resource_id) == nil

      # verifies we return nil on a made up id
      assert DeliveryResolver.from_resource_id("1", 1337) == nil

    end

    test "from_revision_slug/2 returns correct revision", %{ revision1: revision1, latest1: latest1, latest4: latest4 } do

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


    test "from_resource_id/2 returns correct list of revisions", %{ latest1: latest1, latest2: latest2, revision2: revision2, revision1: revision1, latest4: latest4 } do

      assert DeliveryResolver.from_resource_id("1", [revision1.resource_id, revision2.resource_id]) == [revision1, revision2]
      assert DeliveryResolver.from_resource_id("2", [revision1.resource_id, revision2.resource_id]) == [latest1, latest2]

      assert DeliveryResolver.from_resource_id("1", [latest4.resource_id, revision2.resource_id]) == [nil, revision2]
      assert DeliveryResolver.from_resource_id("2", [latest4.resource_id, revision2.resource_id]) == [nil, latest2]

      # verifies we return nil on a made up id
      assert DeliveryResolver.from_resource_id("1", [133799, 18283823]) == [nil, nil]

    end

    test "from_resource_id/2 orders results according to inputs", %{ latest1: latest1, latest2: latest2, revision2: revision2, revision1: revision1, latest4: latest4 } do

      assert DeliveryResolver.from_resource_id("1", [revision2.resource_id, revision1.resource_id]) == [revision2, revision1]
      assert DeliveryResolver.from_resource_id("2", [revision2.resource_id, revision1.resource_id]) == [latest2, latest1]

      assert DeliveryResolver.from_resource_id("1", [revision2.resource_id, latest4.resource_id]) == [revision2, nil]
      assert DeliveryResolver.from_resource_id("2", [revision2.resource_id, latest4.resource_id]) == [latest2, nil]

    end

    test "publication/1 doesn't retrieve the already published publication", %{ pub1: pub1, pub2: pub2 } do

      assert DeliveryResolver.publication("1") == pub1
      assert DeliveryResolver.publication("2") == pub2

    end

    test "root_resource/1 resolves the root revision", %{ container_revision: container_revision } do

      assert DeliveryResolver.root_resource("1") == container_revision
      assert DeliveryResolver.root_resource("2") == container_revision

    end


  end

end
