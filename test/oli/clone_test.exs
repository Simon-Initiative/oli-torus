defmodule Oli.CloneTest do
  use Oli.DataCase

  alias Oli.Authoring.Collaborators
  alias Oli.Publishing
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Authoring.Locks
  alias Oli.Authoring.MediaLibrary
  alias Oli.Authoring.Course.Family
  alias Oli.Authoring.Clone

  describe "project duplication" do
    setup do
      project_map = Oli.Seeder.base_project_with_resource2()

      # Acquire a lock to edit the published_resource mapping in place
      Locks.acquire(project_map.publication.id, project_map.container.resource.id, project_map.author.id)

      {:ok, duplicated_project} = Clone.clone_project(project_map.project.slug, project_map.author)
      Map.put(project_map, :duplicated, Repo.preload(duplicated_project, [:parent_project, :family]))
    end

    test "clone_project/2 creates a new family", %{ project: project, family: family, duplicated: duplicated } do
      assert %Family{} = duplicated.family
      assert family.title <> " Copy" == duplicated.family.title
      assert family.description == duplicated.family.description
      assert family.slug != duplicated.family.slug
    end

    test "clone_project/2 creates a new project", %{ project: project, duplicated: duplicated } do
      assert project.title <> " Copy" == duplicated.title
      assert duplicated.version == "1.0.0"
      assert project.family_id != duplicated.family_id
      assert duplicated.project_id == project.id
    end

    test "clone_project/2 creates a new collaborator", %{ author: author, project: project, duplicated: duplicated } do
      # AuthorProject schema
      collaborator = Collaborators.get_collaborator(author.id, duplicated.id)
      assert collaborator.author_id == author.id
      assert collaborator.project_id == duplicated.id
    end

    test "clone_project/2 creates a new publication", %{ project: project, duplicated: duplicated } do
      new_publication = Publishing.get_unpublished_publication_by_slug!(duplicated.slug)
      base_root_container = AuthoringResolver.root_container(project.slug)

      assert new_publication.project_id == duplicated.id
      assert root_resource_id = base_root_container.resource_id
    end

    test "clone_project/2 clears all locks", %{ publication: publication, container: %{ resource: resource }, duplicated: duplicated } do
      # Lock acquisition is done in setup, since the project is duplicated there

      # Check locks for locked revision in the base course
      assert Enum.empty?(Publishing.retrieve_lock_info([resource.id], publication.id))
    end

    test "clone_all_resource_mappings/2 works", %{ author: author, container: %{ resource: resource }, publication: publication, duplicated: duplicated } do
      # Create a new publication
      {:ok, cloned_publication} = Publishing.create_publication(%{
        project_id: duplicated.id,
        root_resource_id: resource.id,
      })
      [head | tail] = Clone.clone_all_resource_mappings(publication.id, cloned_publication.id)
      # 3 published resources
      assert Enum.count([head | tail]) == 3
      assert head.publication_id == cloned_publication.id
    end

    test "clone_all_media_items/2 works", %{ project: project, duplicated: duplicated } do
      {:ok, dummy_media_item} = MediaLibrary.create_media_item(%{
        url: "www.google.com",
        file_name: "test",
        mime_type: "jpg",
        file_size: 10,
        md5_hash: "123",
        deleted: false,
        project_id: project.id
      })

      cloned = Clone.clone_all_media_items(project.slug, duplicated.id)
      assert Enum.count(cloned) == 1
      assert hd(cloned).project_id == duplicated.id
    end
  end

end
