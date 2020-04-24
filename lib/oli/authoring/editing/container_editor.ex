defmodule Oli.Authoring.Editing.ContainerEditor do
  @moduledoc """
  This module provides high-level editing facilities for project
  containers, mainly around adding and removing and reording
  the items within a container.

  """

  alias Oli.Resources.Revision
  alias Oli.Accounts.Author
  alias Oli.Authoring.Course.Project
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Publishing.ChangeTracker

  def list_all_pages(%Project{} = project) do
    root_resource = AuthoringResolver.root_resource(project.slug)
    AuthoringResolver.from_resource_id(project.slug, root_resource.children)
  end

  def add_new(
    %{objectives: _, children: _, content: _, title: _} = attrs,
    %Author{} = author,
    %Project{} = project
  ) do

    AuthoringResolver.root_resource(project.slug)
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

    with {:ok, %{revision: revision}} <- Oli.Authoring.Course.create_and_attach_resource(project, attrs),
         {:ok, _} <- ChangeTracker.track_revision(project.slug, revision),
         {:ok, _} <- append_to_container(container, project.slug, revision, author)
    do
      {:ok, revision}
    else
      error -> error
    end
  end

  def append_to_container(container, project_slug, revision_to_attach, author) do

    append = %{
      children: [revision_to_attach.resource_id | container.children],
      author_id: author.id
    }
    ChangeTracker.track_revision(project_slug, container, append)
  end


end
