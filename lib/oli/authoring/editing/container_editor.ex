defmodule Oli.Authoring.Editing.ContainerEditor do
  @moduledoc """
  This module provides high-level editing facilities for project
  containers, mainly around adding and removing and reording
  the items within a container.

  """

  import Oli.Authoring.Editing.Utils
  alias Oli.Resources.Revision
  alias Oli.Resources
  alias Oli.Accounts.Author
  alias Oli.Authoring.Course.Project
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Publishing.ChangeTracker
  alias Oli.Authoring.Editing.PageEditor
  alias Oli.Repo
  alias Oli.Authoring.Broadcaster

  @spec edit_page(Oli.Authoring.Course.Project.t(), any, map) :: any
  def edit_page(%Project{} = project, revision_slug, change) do
    # safe guard that we do never allow content or objective changes
    atomized_change =
      for {key, val} <- change,
          into: %{},
          do:
            {if is_binary(key) do
               String.to_atom(key)
             else
               key
             end, val}

    change =
      atomized_change
      |> Map.delete(:content)
      |> Map.delete(:objectives)

    # ensure that changing a page to practice resets the max attempts to 0
    change =
      case Map.get(change, :graded, "true") do
        "false" -> Map.put(change, :max_attempts, 0)
        _ -> change
      end

    result =
      Repo.transaction(fn ->
        revision = AuthoringResolver.from_revision_slug(project.slug, revision_slug)

        case ChangeTracker.track_revision(project.slug, revision, change) do
          {:ok, _} -> AuthoringResolver.from_revision_slug(project.slug, revision_slug)
          {:error, changelist} -> Repo.rollback(changelist)
        end
      end)

    case result do
      {:ok, revision} ->
        Broadcaster.broadcast_revision(revision, project.slug)
        {:ok, revision}

      e ->
        e
    end
  end

  @doc """
  Lists all top level resource revisions contained in a container.
  """
  def list_all_container_children(container, %Project{} = project) do
    AuthoringResolver.from_resource_id(project.slug, container.children)
    |> Repo.preload([:resource, :author])
  end

  @doc """
  Creates and adds a new page or container as a child of a container.
  """
  def add_new(
        %Revision{} = container,
        %{objectives: _, children: _, content: _, title: _} = attrs,
        %Author{} = author,
        %Project{} = project
      ) do
    attrs =
      Map.merge(attrs, %{
        author_id: author.id
      })

    # We want to ensure that the creation and attachment either
    # all succeeds or all fails
    result =
      Repo.transaction(fn ->
        with {:ok, %{revision: revision}} <-
               Oli.Authoring.Course.create_and_attach_resource(project, attrs),
             {:ok, _} <- ChangeTracker.track_revision(project.slug, revision),
             {:ok, _} <- append_to_container(container, project.slug, revision, author) do
          revision
        else
          {:error, e} -> Repo.rollback(e)
        end
      end)

    {status, _} = result

    if status == :ok do
      broadcast_update(container.resource_id, project.slug)
    end

    result
  end

  @doc """
  Moves a page or container into another container.
  """
  def move_to(
        %Revision{} = revision,
        %Revision{} = old_container,
        %Revision{} = new_container,
        %Author{} = author,
        %Project{} = project
      ) do
    # ensure that the removal and attachment either all succeeds or all fails
    result =
      Repo.transaction(fn ->
        with {:ok, _} <- remove_from_container(old_container, project.slug, revision, author),
             {:ok, _} <- append_to_container(new_container, project.slug, revision, author) do
          revision
        else
          {:error, e} -> Repo.rollback(e)
        end
      end)

    {status, _} = result

    if status == :ok do
      broadcast_update(old_container.resource_id, project.slug)
      broadcast_update(new_container.resource_id, project.slug)
    end

    result
  end

  def broadcast_update(resource_id, project_slug) do
    updated_container = AuthoringResolver.from_resource_id(project_slug, resource_id)
    Broadcaster.broadcast_revision(updated_container, project_slug)
  end

  @doc """
  Removes a child from a container, and marks that child as deleted by default.
  """
  def remove_child(container, project, author, revision_slug) do
    with {:ok, %{id: resource_id}} <-
           Resources.get_resource_from_slug(revision_slug) |> trap_nil() do
      children = Enum.filter(container.children, fn id -> id !== resource_id end)

      # Create a change that removes the child
      removal = %{
        children: children,
        author_id: author.id
      }

      # Create a change to mark the child as deleted
      deletion = %{
        deleted: true,
        author_id: author.id
      }

      # Atomically apply the changes
      result =
        Repo.transaction(fn ->
          # It is important to edit the page via PageEditor, since it will ensure
          # that a lock can be acquired before editing. This will not allow the deletion
          # to occur if another user is editing. It *will* allow deletion to occur if
          # this current user is editing this page (like in another tab). This is due
          # to the re-entrant natures of our locks.

          with {:acquired} <- PageEditor.acquire_lock(project.slug, revision_slug, author.email),
               {:ok, _} <- PageEditor.edit(project.slug, revision_slug, author.email, deletion),
               _ <- PageEditor.release_lock(project.slug, revision_slug, author.email),
               {:ok, revision} = ChangeTracker.track_revision(project.slug, container, removal) do
            revision
          else
            {:lock_not_acquired, value} -> Repo.rollback({:lock_not_acquired, value})
            {:error, e} -> Repo.rollback(e)
          end
        end)

      {status, _} = result

      if status == :ok do
        broadcast_update(container.resource_id, project.slug)
      end

      result
    else
      _ -> {:error, :not_found}
    end
  end

  def reorder_child(container, project, author, source, index) do
    # Change here to enable "cross project drag and drop -> if resource is not found (nil),
    # create new resource in this project by cloning the existing resource

    # Get the resource id associated with the source revision

    result =
      Repo.transaction(fn ->
        with {:ok, %{id: resource_id}} <- Resources.get_resource_from_slug(source) |> trap_nil() do
          source_index = Enum.find_index(container.children, fn id -> id == resource_id end)

          # Adjust the insert index based on whether
          # first removing the source would throw off the
          # insertion by 1
          insert_index =
            case source_index do
              nil ->
                index

              s ->
                if s < index do
                  index - 1
                else
                  index
                end
            end

          # Apply the reordering in a way that is as robust as possible to situations
          # where the user that originated the reorder was looking at an out of date
          # version of the page

          # Use filter here to remove the source from anywhere that it was actually found
          children =
            Enum.filter(container.children, fn id -> id !== resource_id end)
            # And insert_at to insert it, in a way that is robust to index positions that
            # don't even make sense
            |> List.insert_at(insert_index, resource_id)

          # Create a change that reorders the children
          reordering = %{
            children: children,
            author_id: author.id
          }

          # Apply that change to the container, generating a new revision
          case ChangeTracker.track_revision(project.slug, container, reordering) do
            {:ok, rev} ->
              updated_container = Oli.Repo.get(Oli.Resources.Revision, rev.revision_id)

              {updated_container, rev}

            e ->
              Repo.rollback(e)
          end
        else
          _ -> Repo.rollback(:not_found)
        end
      end)

    case result do
      {:ok, {updated_container, rev}} ->
        Broadcaster.broadcast_revision(updated_container, project.slug)
        {:ok, rev}

      e ->
        e
    end
  end

  defp remove_from_container(container, project_slug, revision, author) do
    # Create a change that removes the child
    removal = %{
      children: Enum.filter(container.children, fn id -> id !== revision.resource_id end),
      author_id: author.id
    }

    ChangeTracker.track_revision(project_slug, container, removal)
  end

  defp append_to_container(container, project_slug, revision_to_attach, author) do
    append = %{
      children: container.children ++ [revision_to_attach.resource_id],
      author_id: author.id
    }

    ChangeTracker.track_revision(project_slug, container, append)
  end
end
