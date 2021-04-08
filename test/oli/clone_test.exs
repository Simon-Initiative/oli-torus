defmodule Oli.CloneTest do
  use Oli.DataCase

  alias Oli.Authoring.Collaborators
  alias Oli.Publishing
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Authoring.Locks
  alias Oli.Authoring.MediaLibrary
  alias Oli.Authoring.Course.Family
  alias Oli.Authoring.Clone
  alias Oli.Authoring.Editing.PageEditor

  describe "project duplication" do
    setup do
      project_map = Oli.Seeder.base_project_with_resource2()

      # Acquire a lock to edit the published_resource mapping in place
      Locks.acquire(
        project_map.project.slug,
        project_map.publication.id,
        project_map.container.resource.id,
        project_map.author.id
      )

      {:ok, duplicated_project} =
        Clone.clone_project(project_map.project.slug, project_map.author2)

      Map.put(
        project_map,
        :duplicated,
        Repo.preload(duplicated_project, [:parent_project, :family])
      )
    end

    test "clone_project/2 creates a new family", %{family: family, duplicated: duplicated} do
      assert %Family{} = duplicated.family
      assert family.title <> " Copy" == duplicated.family.title
      assert family.description == duplicated.family.description
      assert family.slug != duplicated.family.slug
    end

    test "clone_project/2 creates a new project", %{project: project, duplicated: duplicated} do
      assert project.title <> " Copy" == duplicated.title
      assert duplicated.version == "1.0.0"
      assert project.family_id != duplicated.family_id
      assert duplicated.project_id == project.id
    end

    test "clone_project/2 creates a new collaborator", %{author2: author, duplicated: duplicated} do
      # AuthorProject schema
      collaborator = Collaborators.get_collaborator(author.id, duplicated.id)
      assert collaborator.author_id == author.id
      assert collaborator.project_id == duplicated.id
    end

    test "clone_project/2 creates a new publication", %{project: project, duplicated: duplicated} do
      new_publication = Publishing.get_unpublished_publication_by_slug!(duplicated.slug)
      base_root_container = AuthoringResolver.root_container(project.slug)

      assert new_publication.project_id == duplicated.id
      assert new_publication.root_resource_id == base_root_container.resource_id
    end

    test "clone_project/2 clears all locks", %{
      publication: publication,
      container: %{resource: resource}
    } do
      # Lock acquisition is done in setup, since the project is duplicated there

      # Check locks for locked revision in the base course
      assert Enum.empty?(Publishing.retrieve_lock_info([resource.id], publication.id))
    end

    test "clone_all_published_resources/2 works", %{
      container: %{resource: resource},
      publication: publication,
      duplicated: duplicated
    } do
      # Create a new publication
      {:ok, cloned_publication} =
        Publishing.create_publication(%{
          project_id: duplicated.id,
          root_resource_id: resource.id
        })

      [head | tail] = Clone.clone_all_published_resources(publication.id, cloned_publication.id)
      # 3 published resources
      assert Enum.count([head | tail]) == 3
      assert head.publication_id == cloned_publication.id
    end

    test "clone_all_media_items/2 works", %{project: project, duplicated: duplicated} do
      {:ok, _dummy_media_item} =
        MediaLibrary.create_media_item(%{
          url: "www.google.com",
          file_name: "test",
          mime_type: "jpg",
          file_size: 10,
          md5_hash: "123",
          deleted: false,
          project_id: project.id
        })

      {:ok, {_items, item_count}} =
        MediaLibrary.items(duplicated.slug, %MediaLibrary.ItemOptions{})

      assert item_count == 0

      cloned = Clone.clone_all_media_items(project.slug, duplicated.id)
      assert Enum.count(cloned) == 1
      assert hd(cloned).project_id == duplicated.id
    end

    test "editing a cloned project revision -> in base project", %{
      author: author1,
      duplicated: duplicated,
      project: project,
      page1: page1
    } do
      base_revision = AuthoringResolver.from_resource_id(project.slug, page1.id)
      # Author 1 starts editing the page in the original project
      PageEditor.acquire_lock(project.slug, base_revision.slug, author1.email)

      some_new_content = %{
        "content" => %{"model" => [%{"type" => "p", "children" => [%{"text" => "A paragraph."}]}]}
      }

      PageEditor.edit(project.slug, base_revision.slug, author1.email, some_new_content)

      author1_edit_revision = AuthoringResolver.from_resource_id(project.slug, page1.id)
      # Verify that editing created a new revision
      refute author1_edit_revision.id == base_revision.id
      assert author1_edit_revision.content == some_new_content["content"]

      # Verify that the latest revision in the duplicated course does not have the changes
      duplicated_revision = AuthoringResolver.from_resource_id(duplicated.slug, page1.id)
      refute author1_edit_revision.id == duplicated_revision.id
      refute duplicated_revision.content == some_new_content["content"]
    end

    test "editing a cloned project revision -> in cloned project", %{
      author2: author2,
      duplicated: duplicated,
      project: project,
      page1: page1
    } do
      duplicated_revision = AuthoringResolver.from_resource_id(duplicated.slug, page1.id)
      # Author 2 starts editing the page in the cloned project
      PageEditor.acquire_lock(duplicated.slug, duplicated_revision.slug, author2.email)

      some_new_content = %{
        "content" => %{"model" => [%{"type" => "p", "children" => [%{"text" => "A paragraph."}]}]}
      }

      PageEditor.edit(duplicated.slug, duplicated_revision.slug, author2.email, some_new_content)

      author2_edit_revision =
        AuthoringResolver.from_resource_id(duplicated.slug, duplicated_revision.resource_id)

      # Verify that editing created a new revision
      refute author2_edit_revision.id == duplicated_revision.id
      assert author2_edit_revision.content == some_new_content["content"]

      # Verify that the latest revision in the original course does not have the changes
      base_revision = AuthoringResolver.from_resource_id(project.slug, page1.id)
      refute author2_edit_revision.id == duplicated_revision.id
      refute base_revision.content == some_new_content["content"]
    end
  end
end
