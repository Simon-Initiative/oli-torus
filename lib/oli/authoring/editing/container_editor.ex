defmodule Oli.Authoring.Editing.ContainerEditor do
  @moduledoc """
  This module provides high-level editing facilities for project
  containers, mainly around adding and removing and reording
  the items within a container.

  """

  alias Oli.Resources.Revision
  alias Oli.Publishing
  alias Oli.Accounts.Author
  alias Oli.Authoring.Course.Project
  alias Oli.Repo

  def list_all_pages(%Project{} = project) do
    root_resource = get_root_container(project)
    Publishing.get_unpublished_revisions(project, root_resource.children)
  end

  def add_new(
    %{objectives: _, children: _, content: _, title: _} = attrs,
    %Author{} = author,
    %Project{} = project
  ) do

    get_root_container(project)
    |> add_new(attrs, author, project)
  end

  def add_new(
    %Revision{} = container,
    %{objectives: _, children: _, content: _, title: _} = attrs,
    %Author{} = author,
    %Project{} = project
  ) do

    attrs = Map.merge(attrs, %{
      author_id: author.id,
    })

    with {:ok, %{resource: resource, revision: revision}} <- Oli.Authoring.Course.create_and_attach_resource(project, attrs),
         publication <- Publishing.get_unpublished_publication_by_slug!(project.slug),
         {:ok, mapping} <- Publishing.upsert_published_resource(publication, revision),
         {:ok, container} <- append_to_container(container, publication, revision, author)
    do
      {:ok,
        %{
          resource: resource,
          revision: revision,
          project: project,
          mapping: mapping,
          root_container: container
        }
      }
    else
      error -> error
    end
  end

  def append_to_container(container, publication, revision_to_attach, author) do
    attrs = %{
      children: [revision_to_attach.resource_id | container.children],
      author_id: author.id
    }
    {:ok, revision} = Oli.Resources.create_revision_from_previous(container, attrs)
    {:ok, _} = Publishing.upsert_published_resource(publication, revision)

    {:ok, revision}
  end

  defp get_root_container(project) do
    project
    |> root_resource()
    |> get_latest_resource_revision(project)
  end

  def get_latest_resource_revision(resource, project) do
    publication = Publishing.get_unpublished_publication_by_slug!(project.slug)
    mapping = Publishing.get_resource_mapping!(publication.id, resource.id)

    Oli.Resources.get_revision!(mapping.revision_id)
  end

  defp root_resource(project) do
    project.slug
    |> Publishing.get_unpublished_publication_by_slug!
    |> Repo.preload(:root_resource)
    |> Map.get(:root_resource)
  end


end
