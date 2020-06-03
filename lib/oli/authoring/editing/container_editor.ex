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


  def edit_page(%Project{} = project, revision_slug, change) do

    # safe guard that we do never allow content or title or objective changes
    change = Map.delete(change, :content)
    |> Map.delete(:title)
    |> Map.delete(:objectives)

    Repo.transaction(fn ->

      revision = AuthoringResolver.from_revision_slug(project.slug, revision_slug)

      case Resources.update_revision(revision, change) do
        {:ok, revision} -> revision
        {:error, changelist} -> Repo.rollback(changelist)
      end

    end)

  end


  @doc """
  Lists all top level resource revisions contained in a container.
  """
  def list_all_pages(%Project{} = project) do
    AuthoringResolver.root_resource(project.slug)
    |> list_all_pages(project)
  end

  def list_all_pages(container, %Project{} = project) do
    AuthoringResolver.from_resource_id(project.slug, container.children)
  end

  @doc """
  Creates and adds a new page as a child of a container.
  """
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

    # We want to ensure that the creation and attachment either
    # all succeeds or all fails
    Repo.transaction(fn ->

      with {:ok, %{revision: revision}} <- Oli.Authoring.Course.create_and_attach_resource(project, attrs),
          {:ok, _} <- ChangeTracker.track_revision(project.slug, revision),
          {:ok, _} <- append_to_container(container, project.slug, revision, author)
      do
        revision
      else
        {:error, e} -> Repo.rollback(e)
      end

    end)
  end

  @doc """
  Removes a child from a container, and marks that child as deleted.
  """
  def remove_child(project, author, revision_slug) do
    AuthoringResolver.root_resource(project.slug)
    |> remove_child(project, author, revision_slug)
  end


  def remove_child(container, project, author, revision_slug) do

    with {:ok, %{id: resource_id }} <- Resources.get_resource_from_slug(revision_slug) |> trap_nil()
    do

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
      Repo.transaction(fn ->

        # It is important to edit the page via PageEditor, since it will ensure
        # that a lock can be acquired before editing. This will not allow the deletion
        # to occur if another user is editing. It *will* allow deletion to occur if
        # this current user is editing this page (like in another tab). This is due
        # to the re-entrant natures of our locks.

        with {:ok, _} <- PageEditor.edit(project.slug, revision_slug, author.email, deletion),
         {:ok, revision} = ChangeTracker.track_revision(project.slug, container, removal)
        do
          revision
        else
          {:error, e} -> Repo.rollback(e)
        end

      end)

    else
      _ -> {:error, :not_found}
    end

  end

  @doc """
  Reorders the children of a container, based off of a source revision
  to remove and an index where to insert it within the collection of
  children.
  """
  def reorder_child(project, author, source, index) do
    AuthoringResolver.root_resource(project.slug)
    |> reorder_child(project, author, source, index)
  end


  def reorder_child(container, project, author, source, index) do

    # Change here to enable "cross project drag and drop -> if resource is not found (nil),
    # create new resource in this project by cloning the existing resource

    # Get the resource idd associated with the source revision

    with {:ok, %{id: resource_id }} <- Resources.get_resource_from_slug(source) |> trap_nil()
    do

      source_index = Enum.find_index(container.children, fn id -> id == resource_id end)

      # Adjust the insert index based on whether
      # first removing the source would throw off the
      # insertion by 1
      insert_index = case source_index do
        nil -> index
        s -> if s < index do
          index - 1
        else
          index
        end
      end

      # Apply the reordering in a way that is as robust as possible to situations
      # where the user that originated the reorder was looking at an out of date
      # version of the page

      # Use filter here to remove the source from anywhere that it was actually found
      children = Enum.filter(container.children, fn id -> id !== resource_id end)
      # And insert_at to insert it, in a way that is robust to index positions that
      # don't even make sense
      |> List.insert_at(insert_index, resource_id)

      # Create a change that reorders the children
      reordering = %{
        children: children,
        author_id: author.id
      }

      # Apply that change to the container, generating a new revision
      ChangeTracker.track_revision(project.slug, container, reordering)

    else
      _ -> {:error, :not_found}
    end

  end

  defp append_to_container(container, project_slug, revision_to_attach, author) do
    append = %{
      children: [revision_to_attach.resource_id | container.children],
      author_id: author.id
    }
    ChangeTracker.track_revision(project_slug, container, append)
  end


end
