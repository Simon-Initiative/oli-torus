defmodule Oli.Authoring.Editing.ResourceEditor do
  @moduledoc """
  This module provides content editing facilities for resources.

  """

  alias Oli.Authoring.{Locks, Course, Resources}
  alias Oli.Authoring.Resources.ResourceRevision
  alias Oli.Authoring.Editing.ResourceContext
  alias Oli.Publishing
  alias Oli.Accounts
  alias Oli.Repo
  import Oli.Utils

  @doc """
  Attempts to process an edit for a resource specified by a given
  project and revision slug, for the author specified by email.

  The update parameter is a map containing key-value pairs of the
  attributes of a ResourceRevision that are to be edited. It can
  contain any number of key-value pairs, but the keys must match
  the schema of `%ResourceRevision{}` struct.

  Not acquiring the lock here is considered a failure, as it is
  not an expected condition that a client would encounter. The client
  should have first acquired the lock via `acquire_lock`.

  Returns:

  .`{:ok, %ResourceRevision{}}` when the edit processes successfully the
  .`{:error, {:lock_not_acquired}}` if the lock could not be acquired or updated
  .`{:error, {:not_found}}` if the project, resource, or user cannot be found
  .`{:error, {:not_authorized}}` if the user is not authorized to edit this resource
  .`{:error, {:error}}` unknown error
  """
  @spec edit(String.t, String.t, String.t, %{})
    :: {:ok, %ResourceRevision{}} | {:error, {:not_found}} | {:error, {:error}} | {:error, {:lock_not_acquired}} | {:error, {:not_authorized}}
  def edit(project_slug, revision_slug, author_email, update) do

    with {:ok, author} <- Accounts.get_author_by_email(author_email) |> trap_nil(),
         {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project),
         {:ok, publication} <- Publishing.get_unpublished_publication(project_slug, author.id) |> trap_nil(),
         {:ok, resource} <- Resources.get_resource_from_slugs(project_slug, revision_slug) |> trap_nil()
    do
      Repo.transaction(fn ->

        case Locks.update(publication.id, resource.id, author.id) do

          # If we acquired the lock, we must first create a new revision
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

  @doc """
  Attempts to lock a resource for editing.

  Not acquiring the lock here isn't considered a failure, as it is
  an expected condition that a user could encounter.

  Returns:

  .`{:acquired}` when the lock is acquired
  .`{:lock_not_acquired, user_email}` if the lock could not be acquired
  .`{:error, {:not_found}}` if the project, resource, or user cannot be found
  .`{:error, {:not_authorized}}` if the user is not authorized to edit this resource
  .`{:error, {:error}}` unknown error
  """
  @spec acquire_lock(String.t, String.t, String.t)
    :: {:acquired} | {:lock_not_acquired, String.t} | {:error, {:not_found}} | {:error, {:error}} | {:error, {:not_authorized}}
  def acquire_lock(project_slug, revision_slug, author_email) do

    with {:ok, author} <- Accounts.get_author_by_email(author_email) |> trap_nil(),
         {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project),
         {:ok, publication} <- Publishing.get_unpublished_publication(project_slug, author.id) |> trap_nil(),
         {:ok, resource} <- Resources.get_resource_from_slugs(project_slug, revision_slug) |> trap_nil()
    do
      case Locks.acquire(publication.id, resource.id, author.id) do

        # If we reacquired the lock, we must first create a new revision
        {:acquired} -> {:acquired}

        # error or not able to lock results in a failed edit
        {:lock_not_acquired, {locked_by, _}} -> {:lock_not_acquired, locked_by}

        error -> {:error, error}
      end
    else
      error -> error
    end

  end

  @doc """
  Attempts to release an edit lock.

  Returns:

  .`{:ok, {:released}}` when the lock is acquired
  .`{:error, {:error}` if an unknown error encountered
  .`{:error, {:not_found}}` if the project, resource, or user cannot be found
  .`{:error, {:not_authorized}}` if the user is not authorized to edit this resource
  """
  @spec release_lock(String.t, String.t, String.t)
    :: {:ok, {:released}} | {:error, {:not_found}} | {:error, {:not_authorized}} | {:error, {:error}}
  def release_lock(project_slug, revision_slug, author_email) do

    with {:ok, author} <- Accounts.get_author_by_email(author_email) |> trap_nil(),
         {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project),
         {:ok, publication} <- Publishing.get_unpublished_publication(project_slug, author.id) |> trap_nil(),
         {:ok, resource} <- Resources.get_resource_from_slugs(project_slug, revision_slug) |> trap_nil()
    do
      case Locks.release(publication.id, resource.id, author.id) do
        {:error} -> {:error, {:error}}
        _ -> {:ok, {:released}}
      end
    else
      error -> error
    end

  end

  @doc """
  Creates the context necessary to power a client side resource editor
  for a specific resource / revision.
  """
  def create_context(project_slug, revision_slug, author) do

    with {:ok, publication} <- Publishing.get_unpublished_publication(project_slug, author.id) |> trap_nil(),
         {:ok, resource} <- Resources.get_resource_from_slugs(project_slug, revision_slug) |> trap_nil(),
         {:ok, objectives} <- Publishing.get_published_objectives(publication.id) |> trap_nil()
    do
      case get_latest_revision(publication, resource) do
        nil -> {:error, :not_found}
        revision -> {:ok, create(revision, project_slug, revision_slug, author, objectives)}
      end
    else
      _ -> {:error, :not_found}
    end
  end

  defp create(revision, project_slug, revision_slug, author, all_objectives) do
    %ResourceContext{
      authorEmail: author.email,
      projectSlug: project_slug,
      resourceSlug: revision_slug,
      editorMap: %{},
      objectives: revision.objectives,
      allObjectives: all_objectives,
      title: revision.title,
      resourceType: revision.resource_type.type,
      content: revision.content
    }
  end

  defp authorize_user(author, project) do
    case Accounts.can_access?(author, project) do
      true -> {:ok}
      false -> {:error, {:not_authorized}}
    end
  end

  def get_latest_revision(publication, resource) do
    mapping = Publishing.get_resource_mapping!(publication.id, resource.id)
    revision = Resources.get_resource_revision!(mapping.revision_id)

    Repo.preload(revision, :resource_type)
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

