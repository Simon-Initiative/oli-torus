defmodule Oli.PublishingTest do
  use Oli.DataCase

  alias Oli.Authoring.Course
  alias Oli.Publishing
  alias Oli.Publishing.Publication
  alias Oli.Publishing.PublishedResource
  alias Oli.Resources
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Authoring.Editing.PageEditor
  alias Oli.Authoring.Editing.ObjectiveEditor
  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.Authoring.Locks

  def create_activity(parts, author, project, page_revision, obj_resource_id) do
    # Create a two part activity where each part is tied to one of the objectives above

    objectives =
      Enum.reduce(parts, %{}, fn {part_id, slugs}, m ->
        Map.put(m, part_id, slugs)
      end)

    parts = Enum.map(parts, fn {part_id, _} -> part_id end)
    content = %{"content" => %{"authoring" => %{"parts" => parts}}}

    {:ok, {revision, _}} =
      ActivityEditor.create(project.slug, "oli_multiple_choice", author, content, [])

    # attach just one activity
    update = %{
      "objectives" => %{"attached" => [obj_resource_id]},
      "content" => %{
        "model" => [
          %{
            "type" => "activity-reference",
            "id" => 1,
            "activitySlug" => revision.slug,
            "purpose" => "none"
          }
        ]
      }
    }

    PageEditor.acquire_lock(project.slug, page_revision.slug, author.email)
    assert {:ok, _} = PageEditor.edit(project.slug, page_revision.slug, author.email, update)

    update = %{"objectives" => objectives}

    {:ok, revision} =
      ActivityEditor.edit(
        project.slug,
        page_revision.resource_id,
        revision.resource_id,
        author.email,
        update
      )

    revision
  end

  describe "retrieve_lock_info" do
    setup do
      Seeder.base_project_with_resource2()
    end

    test "retrieves valid lock info", %{
      author: author,
      project: project,
      publication: publication,
      container: %{resource: container_resource}
    } do
      assert Locks.acquire(project.slug, publication.id, container_resource.id, author.id) ==
               {:acquired}

      id = container_resource.id

      assert [%PublishedResource{resource_id: ^id}] =
               Publishing.retrieve_lock_info([container_resource.id], publication.id)
    end

    test "ignores expired locks", %{
      author: author,
      project: project,
      publication: publication,
      container: %{resource: container_resource}
    } do
      assert Locks.acquire(project.slug, publication.id, container_resource.id, author.id) ==
               {:acquired}

      [published_resource] =
        Publishing.retrieve_lock_info([container_resource.id], publication.id)

      Publishing.update_published_resource(published_resource, %{lock_updated_at: yesterday()})

      assert [] = Publishing.retrieve_lock_info([container_resource.id], publication.id)
    end
  end

  describe "publications" do
    setup do
      Seeder.base_project_with_resource2()
    end

    test "find_objective_attachments/2 returns the objective revisions", %{
      author: author,
      project: project,
      publication: publication,
      revision1: revision
    } do
      {:ok, %{revision: obj1}} = ObjectiveEditor.add_new(%{title: "one"}, author, project)
      {:ok, %{revision: obj2}} = ObjectiveEditor.add_new(%{title: "two"}, author, project)
      {:ok, %{revision: obj3}} = ObjectiveEditor.add_new(%{title: "three"}, author, project)

      activity1 =
        create_activity(
          [{"1", [obj1.resource_id]}, {"2", []}],
          author,
          project,
          revision,
          obj1.resource_id
        )

      activity2 =
        create_activity(
          [{"1", [obj1.resource_id]}, {"2", [obj1.resource_id]}],
          author,
          project,
          revision,
          obj1.resource_id
        )

      activity3 =
        create_activity(
          [{"1", [obj1.resource_id]}, {"2", [obj2.resource_id]}],
          author,
          project,
          revision,
          obj1.resource_id
        )

      activity4 =
        create_activity(
          [{"1", [obj2.resource_id]}, {"2", [obj3.resource_id]}],
          author,
          project,
          revision,
          obj1.resource_id
        )

      results = Publishing.find_objective_attachments(obj1.resource_id, publication.id)

      assert length(results) == 5

      # activity 2 should appear twice since it has the objective attached in multiple parts
      assert Enum.filter(results, fn r -> r.id == activity2.id end) |> length == 2

      # the next two have it in only one part
      assert Enum.filter(results, fn r -> r.id == activity1.id end) |> length == 1
      assert Enum.filter(results, fn r -> r.id == activity3.id end) |> length == 1

      # this activity does not have this objective attached at all
      assert Enum.filter(results, fn r -> r.id == activity4.id end) |> length == 0

      # the page has it attached as well
      assert Enum.filter(results, fn r -> r.resource_id == revision.resource_id end) |> length ==
               1

      parent_pages = Publishing.determine_parent_pages([activity4.resource_id], publication.id)
      assert Map.has_key?(parent_pages, activity4.resource_id)
    end
  end

  describe "project publishing" do
    setup do
      Seeder.base_project_with_resource2()
    end

    test "publish_project/1 publishes the active unpublished publication and creates a new working unpublished publication for a project",
         %{publication: publication, project: project} do
      {:ok, %Publication{} = published} = Publishing.publish_project(project)

      # original publication should now be published
      assert published.id == publication.id
      assert published.published == true
    end

    test "publish_project/1 creates a new working unpublished publication for a project",
         %{publication: unpublished_publication, project: project} do
      {:ok, %Publication{} = published_publication} = Publishing.publish_project(project)

      # The published publication should match the original unpublished publication
      assert unpublished_publication.id == published_publication.id

      # the unpublished publication for the project should now be a new different publication
      new_unpublished_publication = Publishing.get_unpublished_publication_by_slug!(project.slug)
      assert new_unpublished_publication.id != unpublished_publication.id

      # mappings should be retained in the original published publication
      unpublished_mappings =
        Publishing.get_published_resources_by_publication(unpublished_publication.id)

      published_mappings =
        Publishing.get_published_resources_by_publication(published_publication.id)

      assert unpublished_mappings == published_mappings

      # mappings should now be replaced with new mappings in the new publication
      assert unpublished_mappings !=
               Publishing.get_published_resources_by_publication(new_unpublished_publication.id)
    end

    test "publish_project/1 publishes all currently locked resources and any new edits to the locked resource result in creation of a new revision for both pages and activities",
         %{
           publication: original_unpublished_publication,
           project: project,
           author: author,
           revision1: original_revision
         } do
      # lock a page
      {:acquired} = PageEditor.acquire_lock(project.slug, original_revision.slug, author.email)

      # lock an activity
      {:ok, %{revision: obj}} = ObjectiveEditor.add_new(%{title: "one"}, author, project)

      revision_with_activity =
        create_activity(
          [{"1", [obj.resource_id]}, {"1", []}],
          author,
          project,
          original_revision,
          obj.resource_id
        )

      {:acquired} =
        PageEditor.acquire_lock(project.slug, revision_with_activity.slug, author.email)

      # Publish the project
      {:ok, %Publication{} = published_publication} = Publishing.publish_project(project)

      # publication should succeed even if a resource is "locked"
      new_unpublished_publication = Publishing.get_unpublished_publication_by_slug!(project.slug)
      assert new_unpublished_publication.id != original_unpublished_publication.id

      # further edits to locked resources should occur in newly created revisions. The locks should not
      # need to be re-acquired through a page reload triggering `PageEditor.acquire_lock`
      # in order to be able to continue editing the new revisions.

      # Update a page
      page_content = %{
        "content" => %{"model" => [%{"type" => "content", "children" => [%{"text" => "A paragraph."}]}]}
      }

      # The page should not be able to be edited without re-acquiring the lock
      {:error, {:lock_not_acquired, _}} =
        PageEditor.edit(project.slug, original_revision.slug, author.email, page_content)

      {:acquired} =
        PageEditor.acquire_lock(project.slug, original_revision.slug, author.email)

      {:ok, updated_page_revision} =
        PageEditor.edit(project.slug, original_revision.slug, author.email, page_content)

      # The updates should occur on the new revision
      assert original_revision.id != updated_page_revision.id
      assert updated_page_revision.content == page_content["content"]

      # But the updates should not be present in the recently-published revision
      published_resource =
        Publishing.get_published_resource!(
          published_publication.id,
          revision_with_activity.resource_id
        )

      published_revision = Resources.get_revision!(published_resource.revision_id)
      assert published_revision.content == revision_with_activity.content
    end

    test "broadcasting the new publication works when publishing", %{project: project} do
      Oli.Authoring.Broadcaster.Subscriber.subscribe_to_new_publications(project.slug)
      {:ok, publication} = Publishing.publish_project(project)
      {:messages, [{:new_publication, pub, project_slug}]} = Process.info(self(), :messages)
      assert pub.id == publication.id
      assert project.slug == project_slug
    end

    test "update_all_section_publications/2 updates all existing sections using the project to the latest publication",
         %{project: project} do
      institution = institution_fixture()

      {:ok, original_publication} = Publishing.publish_project(project)

      {:ok, %Section{id: section_id}} =
        Sections.create_section(%{
          time_zone: "US/Central",
          title: "title",
          context_id: "some-context-id",
          institution_id: institution.id,
          project_id: project.id,
          publication_id: original_publication.id
        })

      assert [%Section{id: ^section_id}] =
               Sections.get_sections_by_publication(original_publication)

      {:ok, original_publication} = Publishing.publish_project(project)

      # update all sections to use the new publication
      new_publication = Publishing.get_unpublished_publication_by_slug!(project.slug)
      Publishing.update_all_section_publications(project, new_publication)

      # section associated with new publication...
      assert [%Section{id: ^section_id}] = Sections.get_sections_by_publication(new_publication)

      # ...and removed from the old one
      assert [] = Sections.get_sections_by_publication(original_publication)
    end

    test "diff_publications/2 returns the changes between 2 publications",
         %{publication: publication, project: project, author: author, revision1: revision} do
      # create a few more resources
      {:ok, %{revision: r2_revision}} =
        Course.create_and_attach_resource(project, %{
          objectives: %{},
          children: [],
          content: %{},
          title: "resource 1",
          resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
          author_id: author.id
        })

      {:ok, %{revision: r3_revision}} =
        Course.create_and_attach_resource(project, %{
          objectives: %{},
          children: [],
          content: %{},
          title: "resource 2",
          resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
          author_id: author.id
        })

      Publishing.upsert_published_resource(publication, r2_revision)
      Publishing.upsert_published_resource(publication, r3_revision)

      # create first publication
      {:ok, %Publication{} = p1} = Publishing.publish_project(project)

      # make some edits
      content = %{"model" => [%{"type" => "content", "children" => [%{"text" => "A paragraph."}]}]}
      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      {:ok, _updated_revision} =
        PageEditor.edit(project.slug, revision.slug, author.email, %{content: content})

      # add another resource
      {:ok, %{revision: r4_revision}} =
        Course.create_and_attach_resource(project, %{
          objectives: %{},
          children: [],
          content: %{},
          title: "resource 3",
          resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
          author_id: author.id
        })

      p2 = Publishing.get_unpublished_publication_by_slug!(project.slug)
      Publishing.upsert_published_resource(p2, r4_revision)

      # delete a resource
      PageEditor.acquire_lock(project.slug, r3_revision.slug, author.email)

      {:ok, _updated_revision} =
        PageEditor.edit(project.slug, r3_revision.slug, author.email, %{deleted: true})

      # generate diff
      diff = Publishing.diff_publications(p1, p2)
      assert Map.keys(diff) |> Enum.count() == 6
      assert {:changed, _} = diff[revision.resource_id]
      assert {:identical, _} = diff[r2_revision.resource_id]
      assert {:deleted, _} = diff[r3_revision.resource_id]
      assert {:added, _} = diff[r4_revision.resource_id]
    end
  end
end
