defmodule Oli.Authoring.Clone do
  import Ecto.Query, warn: false
  import Oli.Authoring.Editing.Utils
  alias Oli.Publishing
  alias Oli.Publishing.{AuthoringResolver, PublishedResource}
  alias Oli.Authoring.{Collaborators, MediaLibrary, Locks}
  alias Oli.Repo
  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.ProjectResource
  alias Oli.Authoring.MediaLibrary.{MediaItem, ItemOptions}

  def clone_project(project_slug, author) do
    Repo.transaction(fn ->
      with {:ok, base_project} <-
             Course.get_project_by_slug(project_slug) |> Repo.preload(:family) |> trap_nil(),
           {:ok, cloned_family} <-
             Course.create_family(%{
               title: base_project.family.title <> " Copy",
               description: base_project.family.description
             }),
           {:ok, cloned_project} <-
             Course.create_project(%{
               title: base_project.title <> " Copy",
               version: "1.0.0",
               family_id: cloned_family.id,
               project_id: base_project.id
             }),
           {:ok, _} <- Collaborators.add_collaborator(author, cloned_project),
           base_root_container <- AuthoringResolver.root_container(base_project.slug),
           {:ok, cloned_publication} <-
             Publishing.create_publication(%{
               project_id: cloned_project.id,
               root_resource_id: base_root_container.resource_id
             }),
           base_publication <- AuthoringResolver.publication(base_project.slug),
           _ <- Locks.release_all(base_publication.id),
           _ <- clone_all_published_resources(base_publication.id, cloned_publication.id),
           _ <- clone_all_project_resources(base_project.id, cloned_project.id),
           _ <- clone_all_media_items(base_project.slug, cloned_project.id) do
        cloned_project
      else
        {:error, error} -> Repo.rollback(error)
      end
    end)
  end

  def clone_all_project_resources(base_project_id, cloned_project_id) do
    Course.list_project_resources(base_project_id)
    |> Enum.map(
      &Repo.insert!(
        Course.change_project_resource(%ProjectResource{}, %{
          resource_id: &1.resource_id,
          project_id: cloned_project_id
        })
      )
    )
  end

  def clone_all_published_resources(base_publication_id, cloned_publication_id) do
    Publishing.get_published_resources_by_publication(base_publication_id)
    |> Enum.map(
      &Repo.insert!(
        Publishing.change_published_resource(%PublishedResource{}, %{
          publication_id: cloned_publication_id,
          resource_id: &1.resource_id,
          revision_id: &1.revision_id
        })
      )
    )
  end

  def clone_all_media_items(base_project_slug, cloned_project_id) do
    {:ok, {media_items, _count}} = MediaLibrary.items(base_project_slug, %ItemOptions{})

    media_items
    |> Enum.map(
      &Repo.insert!(
        MediaLibrary.change_media_item(%MediaItem{}, %{
          url: &1.url,
          file_name: &1.file_name,
          mime_type: &1.mime_type,
          file_size: &1.file_size,
          md5_hash: &1.md5_hash,
          deleted: &1.deleted,
          project_id: cloned_project_id
        })
      )
    )
  end
end
