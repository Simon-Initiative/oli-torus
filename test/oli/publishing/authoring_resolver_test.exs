defmodule Oli.Publishing.AuthoringResolverTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Publishing.AuthoringResolver
  alias Oli.Authoring.Editing.ResourceEditor
  alias Oli.Resources.ResourceType

  describe "authoring resolution" do
    setup do
      Seeder.base_project_with_resource4()
    end

    @tag :flaky
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
      non_existent_resource_id = latest_record_index("resources") + 1
      assert AuthoringResolver.from_resource_id(project.slug, non_existent_resource_id) == nil
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
      r =
        AuthoringResolver.from_resource_id(project.slug, [revision2.resource_id, 123_123_123_123])

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

    test "revisions_of_type/2 returns all non-deleted revisions of a specified type", %{
      author: author,
      project: project
    } do
      {:ok, _alt_group1} =
        ResourceEditor.create(
          project.slug,
          author,
          ResourceType.id_for_alternatives(),
          %{title: "Alt 1", content: %{"options" => []}}
        )

      {:ok, alt_group2} =
        ResourceEditor.create(
          project.slug,
          author,
          ResourceType.id_for_alternatives(),
          %{title: "Alt 2", content: %{"options" => []}}
        )

      {:ok, _alt_group3} =
        ResourceEditor.create(
          project.slug,
          author,
          ResourceType.id_for_alternatives(),
          %{title: "Alt 3", content: %{"options" => []}}
        )

      revisions =
        AuthoringResolver.revisions_of_type(
          project.slug,
          ResourceType.id_for_alternatives()
        )

      assert Enum.count(revisions) == 3
      assert revisions |> Enum.map(& &1.title) |> Enum.sort() == ["Alt 1", "Alt 2", "Alt 3"]

      {:ok, _deleted} = ResourceEditor.delete(project.slug, alt_group2.resource_id, author)

      revisions =
        AuthoringResolver.revisions_of_type(
          project.slug,
          ResourceType.id_for_alternatives()
        )

      assert Enum.count(revisions) == 2
      assert revisions |> Enum.map(& &1.title) |> Enum.sort() == ["Alt 1", "Alt 3"]
    end

    test "get_by_purpose/2 returns all revisions when receive a valid project_slug and purpose",
         %{} do
      {:ok,
       project: project,
       section: _section,
       page_revision: page_revision,
       other_revision: other_revision} = project_section_revisions(%{})

      assert project.slug
             |> AuthoringResolver.get_by_purpose(page_revision.purpose)
             |> length() == 1

      assert project.slug
             |> AuthoringResolver.get_by_purpose(other_revision.purpose)
             |> length() == 1
    end

    test "get_by_purpose/2 returns empty list when receive a invalid project_slug",
         %{} do
      project = insert(:project)

      assert AuthoringResolver.get_by_purpose(project.slug, :foundation) == []
      assert AuthoringResolver.get_by_purpose(project.slug, :application) == []
    end

    test "targeted_via_related_to/2 returns all revisions when receive a valid project_slug and resource_id",
         %{} do
      {:ok,
       project: project,
       section: _section,
       page_revision: page_revision,
       other_revision: _other_revision} = project_section_revisions(%{})

      assert project.slug
             |> AuthoringResolver.targeted_via_related_to(page_revision.resource_id)
             |> length() == 1
    end

    test "targeted_via_related_to/2 returns empty list when don't receive a valid project_slug and resource_id",
         %{} do
      project = insert(:project)

      page_revision =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          title: "Example test revision",
          graded: true,
          content: %{"advancedDelivery" => true}
        )

      assert AuthoringResolver.targeted_via_related_to(project.slug, page_revision.resource_id) ==
               []
    end

    test "all_unique_youtube_intro_videos/1 returns all unique youtube intro videos", %{
      latest2: revision,
      latest3: revision_1,
      latest4: revision_2,
      project: project
    } do
      assert AuthoringResolver.all_unique_youtube_intro_videos(project.slug) == []

      # not youtube urls are ignored
      Oli.Resources.update_revision(revision, %{intro_video: "some_S3_video_url"})
      assert AuthoringResolver.all_unique_youtube_intro_videos(project.slug) == []

      # only unique youtube urls are returned
      Oli.Resources.update_revision(revision_1, %{
        intro_video: "https://www.youtube.com/watch?v=1234"
      })

      Oli.Resources.update_revision(revision_2, %{
        intro_video: "https://www.youtube.com/watch?v=1234"
      })

      assert AuthoringResolver.all_unique_youtube_intro_videos(project.slug) == [
               "https://www.youtube.com/watch?v=1234"
             ]
    end
  end
end
