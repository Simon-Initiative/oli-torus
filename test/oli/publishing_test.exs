defmodule Oli.PublishingTest do
  use Oli.DataCase

  alias Oli.Authoring.Course
  alias Oli.Publishing
  alias Oli.Publishing.Publication
  alias Oli.Resources
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Authoring.Editing.PageEditor
  alias Oli.Authoring.Editing.ObjectiveEditor
  alias Oli.Authoring.Editing.ActivityEditor


  def create_activity(parts, author, project, page_revision, obj_slug) do

    # Create a two part activity where each part is tied to one of the objectives above

    objectives = Enum.reduce(parts, %{}, fn {part_id, slugs}, m ->
      Map.put(m, part_id, slugs)
    end)

    parts = Enum.map(parts, fn {part_id, _} -> part_id end)
    content = %{ "content" => %{"authoring" => %{"parts" => parts}}}

    {:ok, {revision, _}} = ActivityEditor.create(project.slug, "oli_multiple_choice", author, content)

    # attach just one activity
    update = %{ "objectives" => %{ "attached" => [obj_slug]}, "content" => %{ "model" => [%{ "type" => "activity-reference", "id" => 1, "activitySlug" => revision.slug, "purpose" => "none"}]}}
    PageEditor.acquire_lock(project.slug, page_revision.slug, author.email)
    assert {:ok, _} =  PageEditor.edit(project.slug, page_revision.slug, author.email, update)

    update = %{ "objectives" => objectives }
    {:ok, revision} = ActivityEditor.edit(project.slug, page_revision.slug, revision.slug, author.email, update)

    revision

  end

  describe "publications" do

    setup do
      Seeder.base_project_with_resource2()
    end

    test "find_objective_attachments/2 returns the objective revisions", %{author: author, project: project, publication: publication, revision1: revision} do

      {:ok, {:ok, %{revision: obj1}}} = ObjectiveEditor.add_new(%{title: "one"}, author, project)
      {:ok, {:ok, %{revision: obj2}}}  = ObjectiveEditor.add_new(%{title: "two"}, author, project)
      {:ok, {:ok, %{revision: obj3}}}  = ObjectiveEditor.add_new(%{title: "three"}, author, project)

      activity1 = create_activity([{"1", [obj1.slug]}, {"2", []}], author, project, revision, obj1.slug)
      activity2 = create_activity([{"1", [obj1.slug]}, {"2", [obj1.slug]}], author, project, revision, obj1.slug)
      activity3 = create_activity([{"1", [obj1.slug]}, {"2", [obj2.slug]}], author, project, revision, obj1.slug)
      activity4 = create_activity([{"1", [obj2.slug]}, {"2", [obj3.slug]}], author, project, revision, obj1.slug)

      results = Publishing.find_objective_attachments(obj1.resource_id, publication.id)

      assert length(results) == 5

      # activity 2 should appear twice since it has the objective attached in multiple parts
      assert (Enum.filter(results, fn r -> r.id == activity2.id end) |> length) == 2

      # the next two have it in only one part
      assert (Enum.filter(results, fn r -> r.id == activity1.id end) |> length) == 1
      assert (Enum.filter(results, fn r -> r.id == activity3.id end) |> length) == 1

      # this activity does not have this objective attached at all
      assert (Enum.filter(results, fn r -> r.id == activity4.id end) |> length) == 0

      # the page has it attached as well
      assert (Enum.filter(results, fn r -> r.resource_id == revision.resource_id end) |> length) == 1

      parent_pages = Publishing.determine_parent_pages([activity4.resource_id], publication.id)
      assert Map.has_key?(parent_pages, activity4.resource_id)

    end

  end

  describe "project publishing" do

    setup do
      Seeder.base_project_with_resource2()
    end

    test "publish_project/1 publishes the active unpublished publication and creates a new working unpublished publication for a project", %{publication: publication, project: project} do
      {:ok, %Publication{} = published} = Publishing.publish_project(project)

      # original publication should now be published
      assert published.id == publication.id
      assert published.published == true
    end

    test "publish_project/1 creates a new working unpublished publication for a project",
      %{publication: publication, project: project} do

      {:ok, %Publication{} = published} = Publishing.publish_project(project)

      # the unpublished publication for the project should now be a new different publication
      new_publication = Publishing.get_unpublished_publication_by_slug!(project.slug)
      assert new_publication.id != publication.id

      # mappings should be retained in the original published publication
      original_resource_mappings = Publishing.get_resource_mappings_by_publication(publication.id)
      published_resource_mappings = Publishing.get_resource_mappings_by_publication(published.id)
      assert original_resource_mappings == published_resource_mappings

      # mappings should now be replaced with new mappings in the new publication
      assert original_resource_mappings != Publishing.get_resource_mappings_by_publication(new_publication.id)

    end

    test "publish_project/1 publishes all currently locked resources and any new edits to the locked resource result in creation of a new revision",
      %{publication: publication, project: project, author: author, page1: page1, revision1: revision} do

      # lock the resource
      Publishing.get_resource_mapping!(publication.id, page1.id)
      |> Publishing.update_resource_mapping(%{lock_updated_at: now(), locked_by_id: author.id})

      {:ok, %Publication{} = published} = Publishing.publish_project(project)

      # publication should succeed even if a resource is "locked"
      new_publication = Publishing.get_unpublished_publication_by_slug!(project.slug)
      assert new_publication.id != publication.id

      # further edits to the locked resource should occur in a new revision
      content = %{"model" => [%{ "type" => "p", children: [%{ "text" => "A paragraph."}] }] }
      PageEditor.acquire_lock(project.slug, revision.slug, author.email)
      {:ok, updated_revision} = PageEditor.edit(project.slug, revision.slug, author.email, %{ content: content })
      assert revision.id != updated_revision.id

      # further edits should not be present in published resource
      resource_mapping = Publishing.get_resource_mapping!(published.id, revision.resource_id)
      old_revision = Resources.get_revision!(resource_mapping.revision_id)
      assert old_revision.content == revision.content
    end

    test "update_all_section_publications/2 updates all existing sections using the project to the latest publication",
      %{project: project} do
      institution = institution_fixture()

      {:ok, original_publication} = Publishing.publish_project(project)

      {:ok, %Section{id: section_id}} = Sections.create_section(%{
        time_zone: "US/Central",
        title: "title",
        context_id: "some-context-id",
        institution_id: institution.id,
        project_id: project.id,
        publication_id: original_publication.id,
      })

      assert [%Section{id: ^section_id}] = Sections.get_sections_by_publication(original_publication)

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
        {:ok, %{revision: r2_revision}} = Course.create_and_attach_resource(project, %{
          objectives: %{},
          children: [],
          content: %{},
          title: "resource 1",
          resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
          author_id: author.id
        })

        {:ok, %{revision: r3_revision}} = Course.create_and_attach_resource(project, %{
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
        content = %{"model" => [%{ "type" => "p", children: [%{ "text" => "A paragraph."}] }]}
        PageEditor.acquire_lock(project.slug, revision.slug, author.email)
        {:ok, _updated_revision} = PageEditor.edit(project.slug, revision.slug, author.email, %{content: content})

        # add another resource
        {:ok, %{revision: r4_revision}} = Course.create_and_attach_resource(project, %{
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
        {:ok, _updated_revision} = PageEditor.edit(project.slug, r3_revision.slug, author.email, %{deleted: true})

        # generate diff
        diff = Publishing.diff_publications(p1, p2)
        assert Map.keys(diff) |> Enum.count == 6
        assert {:changed, _} = diff[revision.resource_id]
        assert {:identical, _} = diff[r2_revision.resource_id]
        assert {:deleted, _} = diff[r3_revision.resource_id]
        assert {:added, _} = diff[r4_revision.resource_id]
    end

  end

end

