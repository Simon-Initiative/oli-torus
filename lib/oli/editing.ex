defmodule Oli.ResourceEditing do
  @moduledoc """
  This module provides content editing facilities for resources.

  """

  alias Oli.Locks
  alias Oli.Publishing
  alias Oli.Course
  alias Oli.Resources
  alias Oli.Accounts
  alias Oli.Resources.ResourceRevision
  alias Oli.Repo

  @doc """
  Attempts to process an edit for a resource specified by a given
  project and revision slug, for the author specified by email.

  The update parameter is a map containing key-value pairs of the
  attributes of a ResourceRevision that are to be edited. It can
  contain any number of key-value pairs, but the keys must match
  the schema of `%ResourceRevision{}` struct.

  Returns:

  .`{:ok, %ResourceRevision{}}` when the edit processes successfully the
  .`{:error, {:lock_not_acquired}}` if the lock could not be acquired or updated
  .`{:error, {:not_found}}` if the project, resource, or user cannot be found
  .`{:error, {:not_authorized}}` if the user is not authorized to edit this resource
  """
  @spec edit(String.t, String.t, String.t, %{})
    :: {:ok, %ResourceRevision{}} | {:error, {:not_found}} | {:error, {:lock_not_acquired}} | {:error, {:not_authorized}}
  def edit(project_slug, revision_slug, author_email, update) do

    with {:ok, author} <- Accounts.get_author_by_email(author_email) |> trap_nil(),
         {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project),
         {:ok, publication} <- Publishing.get_unpublished_publication(project_slug, author.id) |> trap_nil(),
         {:ok, resource} <- Resources.get_resource_from_slugs(project_slug, revision_slug) |> trap_nil()
    do
      Repo.transaction(fn ->

        case Locks.acquire_or_update(publication.id, resource.id, author.id) do

          # If we reacquired the lock, we must first create a new revision
          {:acquired} -> get_latest_revision(publication, resource)
            |> create_new_revision(publication, resource, author.id)
            |> update_revision(update)

          # A successful lock update means we can safely edit the existing revision
          {:updated} -> get_latest_revision(publication, resource)
            |> update_revision(update)

          # error or not able to lock results in a failed edit
          result -> Repo.rollback(result)
        end

      end)

    else
      error -> error
    end

  end

  defp authorize_user(author, project) do
    case Accounts.can_access?(author, project) do
      true -> {:ok}
      false -> {:error, {:not_authorized}}
    end
  end

  defp trap_nil(result) do
    case result do
      nil -> {:error, {:not_found}}
      _ -> {:ok, result}
    end
  end

  defp get_latest_revision(publication, resource) do
    mapping = Publishing.get_resource_mapping!(publication.id, resource.id)
    Resources.get_resource_revision!(mapping.revision_id)
  end

  defp create_new_revision(previous, publication, resource, author_id) do

    {:ok, revision} = Resources.create_resource_revision(%{
      children: previous.children,
      content: previous.content,
      objectives: previous.objectives,
      deleted: previous.deleted,
      slug: previous.slug,
      title: previous.title,
      author_id: author_id,
      resource_id: previous.resource_id,
      previous_revision_id: previous.id,
      resource_type_id: previous.resource_type_id
    })

    mapping = Publishing.get_resource_mapping!(publication.id, resource.id)
    {:ok, _mapping} = Publishing.update_resource_mapping(mapping, %{ revision_id: revision.id })

    revision
  end

  defp update_revision(revision, update) do
    {:ok, updated} = Resources.update_resource_revision(revision, update)
    updated
  end

end

