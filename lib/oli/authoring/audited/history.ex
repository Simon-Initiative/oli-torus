defmodule Oli.Authoring.Audited.History do
  @moduledoc false

  # Revision history commands of `Oli.Authoring.Audited`, which validates their arguments.
  # Moved from the `mimic_edit/3` copies in `OliWeb.Workspaces.CourseAuthor.HistoryLive` and
  # `OliWeb.RevisionHistory`, and from their in-place attribute edit. Each records
  # `authoring_content_replaced` with a `reason`, the revisions involved, and the changed
  # settings, never the content itself.

  import Ecto.Query, only: [from: 2]
  import Oli.Authoring.Audited.Support, only: [lock_working_mappings: 2, record_replacement: 5]

  alias Oli.Authoring.Broadcaster
  alias Oli.Authoring.Course.ProjectResource
  alias Oli.Publishing
  alias Oli.Publishing.{AuthoringResolver, ChangeTracker}
  alias Oli.Repo
  alias Oli.Resources
  alias Oli.Resources.Revision

  # Revision attributes the history views let an administrator edit in place
  @editable_attributes [:children, :objectives]

  ## Commands

  def restore_revision(context, project, resource_id, revision_id) do
    case Repo.get(Revision, revision_id) do
      %Revision{resource_id: ^resource_id} = selected ->
        replace(context, project, resource_id, selected, selected.content, "history_restore")

      _other ->
        {:error, :not_found}
    end
  end

  def replace_revision_content(context, project, resource_id, content),
    do: replace(context, project, resource_id, :head, content, "json_edit")

  def update_revision_attribute(context, project, revision_id, key, value)
      when key in @editable_attributes do
    Repo.transaction(fn ->
      with %Revision{} = revision <- lock_revision(project, revision_id),
           {:ok, updated} <- Resources.update_revision(revision, %{key => value}),
           :ok <- record_replacement(context, project, revision, updated, "attribute_edit") do
        updated
      else
        nil -> Repo.rollback(:not_found)
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def update_revision_attribute(_context, _project, _revision_id, _key, _value),
    do: {:error, :protected}

  ## Writes

  # Creates and tracks a new head revision of the resource with `content` and the title,
  # objectives, and scoring settings of `base` (`:head` takes them from the current head), as
  # the history views did. The new revision's author is the author of `base`, as before. Clears
  # the editing lock first, so an open editor cannot overwrite the replacement.
  defp replace(context, project, resource_id, base, content, reason) do
    publication = Publishing.project_working_publication(project.slug)

    Repo.transaction(fn ->
      lock_working_mappings(project, [resource_id])

      with %{} = mapping <- Publishing.get_published_resource(publication.id, resource_id),
           {:ok, _mapping} <-
             Publishing.update_published_resource(mapping, %{
               lock_updated_at: nil,
               locked_by_id: nil
             }),
           %Revision{} = head <- AuthoringResolver.from_resource_id(project.slug, resource_id),
           base = base_revision(base, head),
           {:ok, revision} <-
             Resources.create_revision_from_previous(head, %{
               author_id: base.author_id,
               content: content,
               title: base.title,
               objectives: base.objectives,
               scoring_strategy_id: base.scoring_strategy_id,
               graded: base.graded,
               max_attempts: base.max_attempts
             }),
           {:ok, revision} <- ChangeTracker.track_revision(project.slug, revision),
           :ok <- record_replacement(context, project, head, revision, reason) do
        revision
      else
        nil -> Repo.rollback(:not_found)
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> tap(fn
      {:ok, revision} -> Broadcaster.broadcast_revision(revision, project.slug)
      _error -> :ok
    end)
  end

  defp base_revision(:head, head), do: head
  defp base_revision(%Revision{} = base, _head), do: base

  # Locks the working mapping of the revision's resource and reads the revision again, only
  # when the resource belongs to the project.
  defp lock_revision(project, revision_id) do
    with %Revision{resource_id: resource_id} <- Repo.get(Revision, revision_id),
         true <-
           Repo.exists?(
             from(pr in ProjectResource,
               where: pr.project_id == ^project.id and pr.resource_id == ^resource_id
             )
           ) do
      lock_working_mappings(project, [resource_id])
      Repo.get(Revision, revision_id)
    else
      _other -> nil
    end
  end
end
