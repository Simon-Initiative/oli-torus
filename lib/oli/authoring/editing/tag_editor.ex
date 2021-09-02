defmodule Oli.Authoring.Editing.TagEditor do
  @moduledoc """
  This module provides content editing facilities for activities.

  """

  import Oli.Authoring.Editing.Utils
  alias Oli.Resources.Revision
  alias Oli.Authoring.Course
  alias Oli.Publishing.AuthoringResolver

  import Ecto.Query, warn: false

  @doc """
  Retrieves a list of all tags for a given project.

  Returns:

  .`{:ok, [%Revision{}]}` when the tags are retrieved
  .`{:error, {:not_found}}` if the project is not found
  """
  @spec list(String.t(), any()) ::
          {:ok, [%Revision{}]} | {:error, {:not_found}}
  def list(project_slug, author) do
    with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project) do
      case Oli.Publishing.get_unpublished_revisions_by_type(project_slug, "tag") do
        nil -> {:error, {:not_found}}
        revisions -> {:ok, Enum.filter(revisions, fn r -> !r.deleted end)}
      end
    else
      error -> error
    end
  end

  @doc """
  Applies an edit to a tag, always generating a new revision to capture the edit.

  Returns:

  .`{:ok, revision}` when the resource is edited
  .`{:error, {:not_found}}` if the project or tag or user cannot be found
  .`{:error, {:not_authorized}}` if the user is not authorized to edit this project
  .`{:error, {:error}}` unknown error
  """
  @spec edit(String.t(), any(), String.t(), map()) ::
          {:ok, %Revision{}}
          | {:error, {:not_found}}
          | {:error, {:error}}
          | {:error, {:not_authorized}}
  def edit(project_slug, resource_id, author, update) do
    with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project),
         {:ok, revision} <-
           AuthoringResolver.from_resource_id(project_slug, resource_id) |> trap_nil() do
      Oli.Publishing.ChangeTracker.track_revision(project_slug, revision, update)
    else
      error -> error
    end
  end

  @doc """
  Creates a new tag resource with given attributes as part of its initial revision.
  """
  def create(project_slug, author, attrs) do
    with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project),
         {:ok, publication} <-
           Oli.Publishing.project_working_publication(project_slug) |> trap_nil(),
         {:ok, revision} <-
           Oli.Resources.create_new(attrs, Oli.Resources.ResourceType.get_id_by_type("tag")),
         {:ok, _} <-
           Course.create_project_resource(%{
             project_id: project.id,
             resource_id: revision.resource_id
           })
           |> trap_nil(),
         {:ok, _mapping} <-
           Oli.Publishing.create_published_resource(%{
             publication_id: publication.id,
             resource_id: revision.resource_id,
             revision_id: revision.id
           }) do
      {:ok, revision}
    else
      error -> error
    end
  end
end
