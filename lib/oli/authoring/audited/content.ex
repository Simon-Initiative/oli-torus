defmodule Oli.Authoring.Audited.Content do
  @moduledoc false

  # Content and media removal commands of `Oli.Authoring.Audited`, which validates their
  # arguments, and the removal writes they run. The writes were moved unchanged from
  # `ContainerEditor`, the curriculum LiveViews, `ResourceEditor`, `BibEntryEditor`, and
  # `MediaLibrary`, except that broadcasts run after commit.

  import Ecto.Query, only: [from: 2]

  import Oli.Authoring.Audited.Support,
    only: [
      latest_revisions: 2,
      lock_working_mappings: 2,
      record: 2,
      record_all: 2,
      resource_ids: 1
    ]

  import Oli.Authoring.Editing.Utils, only: [authorize_user: 2, trap_nil: 1]

  alias Oli.Auditing.Changes
  alias Oli.Auditing.EventCatalog.Fields
  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.Project
  alias Oli.Authoring.Editing
  alias Oli.Authoring.Audited.{Activities, Pages}
  alias Oli.Authoring.Editing.{ContainerEditor, PageEditor, ResourceEditor}
  alias Oli.Authoring.MediaLibrary.MediaItem
  alias Oli.Publishing.{AuthoringResolver, ChangeTracker}
  alias Oli.Repo
  alias Oli.Resources
  alias Oli.Resources.Revision

  ## Commands

  def remove_from_curriculum(context, container, project, author, revision_slug) do
    resource_ids = resource_ids_for_slug(revision_slug)

    project
    |> removing(context, resource_ids, [cascade: true], fn ->
      remove_child(container, project, author, revision_slug)
    end)
    |> tap(fn
      {:ok, _} -> ContainerEditor.broadcast_update(container.resource_id, project.slug)
      _error -> :ok
    end)
  end

  def delete_unattached_page(context, project, revision_slug) do
    removing(project, context, resource_ids_for_slug(revision_slug), [], fn ->
      delete_unattached(project.slug, revision_slug)
    end)
  end

  def delete_activity(context, project_slug, lock_id, activity_id, author) do
    removing(project_slug, context, resource_ids([activity_id]), [], fn ->
      Activities.delete(project_slug, lock_id, activity_id, author)
    end)
  end

  def delete_activities(context, project_slug, activity_ids, author) do
    removing(project_slug, context, resource_ids(activity_ids), [], fn ->
      Activities.delete_bulk(project_slug, activity_ids, author)
    end)
  end

  def delete_alternatives_group(context, project_slug, resource_id, author) do
    removing(project_slug, context, resource_ids([resource_id]), [], fn ->
      mark_group_deleted(project_slug, resource_id, author)
    end)
  end

  def delete_bib_entry(context, project_slug, resource_id, author) do
    removing(project_slug, context, resource_ids([resource_id]), [], fn ->
      mark_bib_entry_deleted(project_slug, resource_id, author)
    end)
  end

  def delete_media(context, project_slug, media_ids) do
    Repo.transaction(fn ->
      with {:ok, items} <- mark_media_deleted(project_slug, media_ids),
           :ok <- record_all(items, &record_media_deleted(context, &1)) do
        length(items)
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  # Locks the working-publication mappings of `resource_ids`, reads their revisions, runs
  # `write`, and records a removal for each resource that `write` deleted. With `cascade: true`,
  # the event also lists the embedded activities that the write deleted.
  defp removing(project_slug, context, resource_ids, opts, write) when is_binary(project_slug) do
    case Course.get_project_by_slug(project_slug) do
      # The write reports a missing project with its usual error
      nil -> write.()
      project -> removing(project, context, resource_ids, opts, write)
    end
  end

  defp removing(%Project{} = project, context, resource_ids, opts, write) do
    Repo.transaction(fn ->
      lock_working_mappings(project, resource_ids)
      before = latest_revisions(project, resource_ids)
      embedded = if opts[:cascade], do: embedded_activities(project, before), else: %{}

      with {:ok, result} <- write.(),
           after_state = latest_revisions(project, resource_ids),
           removed_embedded = removed(embedded, latest_revisions(project, Map.keys(embedded))),
           :ok <-
             record_all(resource_ids, fn id ->
               record_removal(context, project, before[id], after_state[id], removed_embedded)
             end) do
        result
      else
        {:error, reason} -> Repo.rollback(reason)
        other -> Repo.rollback(other)
      end
    end)
  end

  defp resource_ids_for_slug(revision_slug) do
    case Oli.Resources.get_resource_from_slug(revision_slug) do
      nil -> []
      resource -> [resource.id]
    end
  end

  # Activities embedded in the pages about to be removed, with their current revisions.
  defp embedded_activities(project, revisions) do
    ids =
      revisions
      |> Map.values()
      |> Enum.flat_map(&(&1.content |> Editing.Utils.activity_references() |> MapSet.to_list()))
      |> Enum.uniq()

    latest_revisions(project, ids)
  end

  defp removed(before, after_state) do
    before
    |> Enum.filter(fn {id, revision} ->
      not revision.deleted and match?(%Revision{deleted: true}, after_state[id])
    end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
  end

  @doc """
  Records the removal of a resource when `before` was not deleted and `after_rev` is; records
  nothing otherwise. `embedded` lists the activity IDs the removal deleted with it.
  """
  def record_removal(context, project, %Revision{deleted: false} = before, after_rev, embedded)
      when is_struct(after_rev, Revision) and after_rev.deleted do
    removed_activity_ids =
      before.content
      |> Editing.Utils.activity_references()
      |> MapSet.to_list()
      |> Enum.filter(&(&1 in embedded))
      |> Enum.sort()

    record(context, %{
      event_type: removal_event_type(before),
      entity: {:resource, before.resource_id, %{title: before.title, slug: before.slug}},
      scope: %{project_id: project.id, resource_id: before.resource_id},
      refs: [
        %{role: :previous, type: :revision, id: before.id, label: before.title},
        %{role: :resulting, type: :revision, id: after_rev.id, label: after_rev.title}
      ],
      changes: Changes.diff(%{deleted: false}, %{deleted: true}, Fields.authoring_content()),
      details:
        case removed_activity_ids do
          [] -> %{}
          ids -> %{removed_activity_ids: ids}
        end,
      event_key: "resource:#{before.resource_id}:removed"
    })
  end

  # Missing, already deleted, or not deleted by the write: nothing to record
  def record_removal(_context, _project, _before, _after, _embedded), do: :ok

  defp removal_event_type(%Revision{scope: :banked, resource_type_id: type_id}) do
    case type_id == Oli.Resources.ResourceType.id_for_activity() do
      true -> :bank_question_deleted
      false -> :authoring_content_removed
    end
  end

  defp removal_event_type(_revision), do: :authoring_content_removed

  defp record_media_deleted(_context, %MediaItem{deleted: true}), do: :ok

  defp record_media_deleted(context, %MediaItem{} = item) do
    record(context, %{
      event_type: :media_deleted,
      entity: {:media_item, item.id, %{title: item.file_name}},
      scope: %{project_id: item.project_id},
      changes: Changes.diff(%{deleted: false}, %{deleted: true}, Fields.authoring_content()),
      details: %{file_name: item.file_name, mime_type: item.mime_type},
      event_key: "media:#{item.id}:deleted"
    })
  end

  ## Writes

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
             {:ok, edited} <- Pages.edit(project.slug, revision_slug, author.email, deletion),
             _ <- Pages.broadcast(edited, project.slug),
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
  def mark_group_deleted(project_slug, resource_id, author),
    do: ResourceEditor.edit(project_slug, resource_id, author, %{deleted: true})

  @doc "Marks a bibliography entry as deleted."
  def mark_bib_entry_deleted(project_slug, resource_id, author) do
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
  def mark_media_deleted(project_slug, media_ids) do
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
