defmodule Oli.PublishingTest do
  use Oli.DataCase

  alias Oli.Authoring.Course
  alias Oli.Publishing
  alias Oli.Publishing.Publication
  alias Oli.Resources
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Authoring.Editing.PageEditor

  describe "publications" do

    setup do
      Seeder.base_project_with_resource2()
    end

    test "get_published_objectives/1 returns the objective revisions", _ do

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

