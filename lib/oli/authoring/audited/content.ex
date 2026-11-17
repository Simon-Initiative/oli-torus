defmodule Oli.Authoring.Audited.Content do
  @moduledoc false

  # Content and media removal writes, private to `Oli.Authoring.Audited`, which records each
  # removal. Moved unchanged from `ContainerEditor`, the curriculum LiveViews, `ResourceEditor`,
  # `BibEntryEditor`, and `MediaLibrary`, except that broadcasts run in the facade after commit.

  import Ecto.Query, only: [from: 2]
  import Oli.Authoring.Editing.Utils, only: [authorize_user: 2, trap_nil: 1]

  alias Oli.Authoring.Course
  alias Oli.Authoring.Editing.{PageEditor, ResourceEditor}
  alias Oli.Authoring.MediaLibrary.MediaItem
  alias Oli.Publishing.{AuthoringResolver, ChangeTracker}
  alias Oli.Repo
  alias Oli.Resources

  @doc """
  Removes a child from a container and marks the child as deleted. The child is deleted
  through `PageEditor`, so the deletion fails while another author holds its lock, and the
  activities it embeds are marked as deleted with it.
  """
  def remove_child(container, project, author, revision_slug) do
    with {:ok, %{id: resource_id}} <-
           Resources.get_resource_from_slug(revision_slug) |> trap_nil() do
      children = Enum.filter(container.children, fn id -> id !== resource_id end)
      removal = %{children: children, author_id: author.id}
      deletion = %{deleted: true, author_id: author.id}

      Repo.transaction(fn ->
        # Locks are re-entrant: the deletion goes ahead when this author is editing the page
        # (in another tab, for example), and fails when another author is.
        with {:acquired} <- PageEditor.acquire_lock(project.slug, revision_slug, author.email),
             {:ok, _} <- PageEditor.edit(project.slug, revision_slug, author.email, deletion),
             _ <- PageEditor.release_lock(project.slug, revision_slug, author.email),
             {:ok, revision} <- ChangeTracker.track_revision(project.slug, container, removal) do
          revision
        else
          {:lock_not_acquired, value} -> Repo.rollback({:lock_not_acquired, value})
          {:error, e} -> Repo.rollback(e)
        end
      end)
    else
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Marks a page that belongs to no container as deleted. Unlike `remove_child/4`, this takes no
  lock and leaves the page's activities as they are.
  """
  def delete_unattached(project_slug, revision_slug) do
    case AuthoringResolver.from_revision_slug(project_slug, revision_slug) do
      nil -> {:error, :not_found}
      revision -> ChangeTracker.track_revision(project_slug, revision, %{deleted: true})
    end
  end

  @doc "Marks an alternatives group as deleted."
  def delete_alternatives_group(project_slug, resource_id, author),
    do: ResourceEditor.edit(project_slug, resource_id, author, %{deleted: true})

  @doc "Marks a bibliography entry as deleted."
  def delete_bib_entry(project_slug, resource_id, author) do
    with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project),
         {:ok, revision} <-
           AuthoringResolver.from_resource_id(project_slug, resource_id) |> trap_nil() do
      ChangeTracker.track_revision(project_slug, revision, %{"deleted" => true})
    end
  end

  @doc """
  Marks media items as deleted, selected by ID only, and returns the selected rows as they were
  before the update. The stored files are kept.
  """
  def delete_media(project_slug, media_ids) do
    case Course.get_project_by_slug(project_slug) do
      nil ->
        {:error, {:not_found}}

      _project ->
        items =
          from(m in MediaItem,
            where: m.id in ^media_ids,
            order_by: m.id,
            lock: "FOR UPDATE"
          )
          |> Repo.all()

        from(m in MediaItem, where: m.id in ^media_ids)
        |> Repo.update_all(set: [deleted: true])

        {:ok, items}
    end
  end
end
