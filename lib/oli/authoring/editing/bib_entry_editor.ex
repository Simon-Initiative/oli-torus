defmodule Oli.Authoring.Editing.BibEntryEditor do
  @moduledoc """
  This module provides content editing facilities for activities.

  """

  import Oli.Authoring.Editing.Utils
  alias Oli.Resources.{Revision, ResourceType}
  alias Oli.Publishing.{AuthoringResolver, PublishedResource}
  alias Oli.Authoring.Course
  alias Oli.Repo.{Paging}
  alias Oli.Repo

  import Ecto.Query, warn: false

  @doc """
  Retrieves a list of all bib_entries for a given project.

  Returns:

  .`{:ok, [%Revision{}]}` when the bib_entries are retrieved
  .`{:error, {:not_found}}` if the project is not found
  """
  @spec list(String.t(), any()) ::
          {:ok, [%Revision{}]} | {:error, {:not_found}}
  def list(project_slug, author) do
    with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project) do
      case Oli.Publishing.get_unpublished_revisions_by_type(project_slug, "bibentry") do
        nil -> {:error, {:not_found}}
        revisions -> {:ok, Enum.filter(revisions, fn r -> !r.deleted end)}
      end
    else
      error -> error
    end
  end

  @doc """
  Retrieves a paged list of bib_entries for a given project.

  Returns:

  .`{:ok, [%Revision{}]}` when the bib_entries are retrieved
  .`{:error, {:not_found}}` if the project is not found
  """
  @spec retrieve(nil | binary, any, Oli.Repo.Paging.t()) ::
          {:error, {:not_authorized} | {:not_found}} | {:ok, list}
  def retrieve(project_slug, author, %Paging{limit: limit, offset: offset}) do
    with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project) do
      case paged_bib_entrys(project_slug, %Paging{limit: limit, offset: offset}) do
        nil ->
          {:error, {:not_found}}

        revisions ->
          revision_list =
            Enum.reduce(revisions, %{total_count: 0, rows: []}, fn e, m ->
              Map.put(m, :total_count, e.full_count)
              |> Map.put(:rows, Map.get(m, :rows) ++ [e.rev])
            end)

          {:ok, revision_list}
      end
    else
      error -> error
    end
  end

  defp paged_bib_entrys(project_slug, %Paging{limit: limit, offset: offset}) do
    publication_id = Oli.Publishing.project_working_publication(project_slug).id
    resource_type_id = ResourceType.get_id_by_type("bibentry")

    query =
      from rev in Revision,
        join: mapping in PublishedResource,
        on: mapping.revision_id == rev.id,
        distinct: rev.resource_id,
        where:
          mapping.publication_id == ^publication_id and
            rev.resource_type_id == ^resource_type_id and
            rev.deleted == false,
        limit: ^limit,
        offset: ^offset,
        preload: :resource_type,
        select: %{rev: rev, full_count: fragment("COUNT(?) OVER()", rev.id)}

    Repo.all(query)
  end

  @doc """
  Applies an edit to a bibentry, always generating a new revision to capture the edit.

  Returns:

  .`{:ok, revision}` when the resource is edited
  .`{:error, {:not_found}}` if the project or bibentry or user cannot be found
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
  Deletes a bibentry, always generating a new revision to capture the deletion.

  Returns:

  .`{:ok, revision}` when the resource is deleted
  .`{:error, {:not_found}}` if the project or bibentry or user cannot be found
  .`{:error, {:not_authorized}}` if the user is not authorized to edit this project
  .`{:error, {:error}}` unknown error
  """
  @spec delete(String.t(), any(), String.t()) ::
          {:ok, %Revision{}}
          | {:error, {:not_found}}
          | {:error, {:error}}
          | {:error, {:not_authorized}}
  def delete(project_slug, resource_id, author) do
    update = %{"deleted" => true}

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
    Repo.transaction(fn ->
      with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
           {:ok} <- authorize_user(author, project),
           {:ok, publication} <-
             Oli.Publishing.project_working_publication(project_slug) |> trap_nil(),
           {:ok, revision} <-
             Oli.Resources.create_new(
               attrs,
               Oli.Resources.ResourceType.get_id_by_type("bibentry")
             ),
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
        error ->
          Repo.rollback(error)
          error
      end
    end)
  end
end
