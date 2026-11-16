defmodule Oli.Publishing.Audited do
  @moduledoc """
  Application boundary for audited publication commands.

  `publish_project/4` records `project_published` inside the transaction that marks the working
  publication as published, so the event exists only for a publication that committed. The
  bookkeeping around it (the new working publication, unique-ID marking, and copied mappings) is
  part of the same publication and records nothing on its own.

  `update_visibility_grants/3` records the authors and institutions granted or denied access to
  a restricted project as `visibility_grants` added or removed in `project_settings_changed`.

  Commands do not authorize the actor; callers keep their existing authorization.
  """

  # This configuration is what makes CI fail when a caller bypasses this facade.
  # Keep the boundary top-level and never export internal modules. Outgoing checks are off
  # because this boundary calls into Oli, which depends on it; incoming checks stay on.
  use Boundary, top_level?: true, exports: [], check: [out: false]

  import Ecto.Query, only: [from: 2]

  alias Oli.Auditing
  alias Oli.Auditing.Context
  alias Oli.Authoring.{Clone, Locks}
  alias Oli.Authoring.Course.{Project, ProjectVisibility}
  alias Oli.Publishing
  alias Oli.Publishing.Publications.{Publication, PublicationDiff}
  alias Oli.Repo

  @doc """
  Publishes the working publication of `project` and creates a new working publication.

  `author_id` owns the editing locks taken while publishing; it is usually the actor of
  `context`. Returns the published publication, or `{:error, message}` when another author
  published in between, as before. A failed audit write rolls the publication back.

  Inside an enclosing transaction (archive ingest), both steps run as savepoints of it.
  """
  @spec publish_project(Context.t(), %Project{}, String.t() | nil, pos_integer()) ::
          {:ok, %Publication{}} | {:error, term()}
  def publish_project(%Context{} = context, %Project{} = project, description, author_id) do
    # Force acquire all locks for the active publication, so that no other user can edit it
    # while it is being published. This runs in an upfront, separate transaction so that the
    # locks are immediately visible to other users.
    {:ok, id} =
      Repo.transaction(fn ->
        active_publication = Publishing.project_working_publication(project.slug)
        Locks.acquire_all(active_publication.id, author_id)

        active_publication.id
      end)

    case Repo.transaction(fn -> publish(context, project, description, id) end) do
      {:error, :interupted_by_another_user} ->
        Locks.release_all(id)

        {:error, "Another user has modified the active publication. Please try again."}

      other ->
        other
    end
  end

  defp publish(context, project, description, id) do
    # Make sure that the active publication has not been modified by another user since the
    # locks were acquired. This could happen if another user published in between the two
    # transactions.
    active_publication = Publishing.project_working_publication(project.slug)

    if active_publication.id != id do
      Repo.rollback(:interupted_by_another_user)
    else
      with latest_published_publication <-
             Publishing.get_latest_published_publication_by_slug(project.slug),
           now <- DateTime.utc_now(),

           # If the active publication has not had its "ids_added" flag set, update all page
           # and activity resources to ensure that unique ids exist. This is a one-time
           # operation for the active publication.
           {:ok, _} <- Oli.Publishing.UniqueIds.add_unique_ids(active_publication),

           # Diff publications to determine the new version number.
           %PublicationDiff{edition: edition, major: major, minor: minor} <-
             Publishing.diff_publications(latest_published_publication, active_publication),

           # Create a new publication to capture all further edits.
           {:ok, new_publication} <-
             Publishing.create_publication(%{
               root_resource_id: active_publication.root_resource_id,
               project_id: active_publication.project_id
             }),

           # Release all locks.
           _ <- Locks.release_all(active_publication.id),

           # Clone mappings for resources, activities, and objectives. This removes all active
           # locks, forcing the user to refresh the page to re-acquire the lock.
           _ <- Clone.clone_all_published_resources(active_publication.id, new_publication.id),
           {:ok, _} <- Publishing.insert_revision_part_records(active_publication.id),

           # Set the active publication to published.
           {:ok, publication} <-
             Publishing.update_publication(active_publication, %{
               published: now,
               description: description,
               edition: edition,
               major: major,
               minor: minor
             }),
           :ok <- record(context, project, publication, latest_published_publication) do
        Oli.Authoring.Broadcaster.broadcast_publication(publication, project.slug)

        publication
      else
        error -> Repo.rollback(error)
      end
    end
  end

  defp record(context, project, publication, previous) do
    version = "#{publication.edition}.#{publication.major}.#{publication.minor}"

    refs =
      [%{role: :resulting, type: :publication, id: publication.id, label: version}] ++
        case previous do
          %Publication{id: id} = previous ->
            [
              %{
                role: :previous,
                type: :publication,
                id: id,
                label: "#{previous.edition}.#{previous.major}.#{previous.minor}"
              }
            ]

          nil ->
            []
        end

    proposal = %{
      event_type: :project_published,
      entity: {:project, project.id, project},
      scope: %{project_id: project.id},
      refs: refs,
      event_key: "project:#{project.id}:published",
      details: %{
        project_title: project.title,
        publication_id: publication.id,
        description: publication.description,
        version: version
      }
    }

    with {:ok, changeset} <- Auditing.build(context, proposal),
         {:ok, _event} <- Auditing.insert(changeset) do
      :ok
    end
  end

  @typedoc "An author or institution that may see a restricted project."
  @type grant :: {:author, pos_integer()} | {:institution, pos_integer()}

  @doc """
  Grants access to the project with ID `project_id` to the authors and institutions in `:add`,
  and removes the grants in `:remove`, in one transaction. Grants that already exist (when
  adding) or do not exist (when removing) are skipped. Records one `project_settings_changed`
  for the added grants and one for the removed grants; a call that changes nothing records no
  event. Returns the project's grants afterwards.
  """
  @spec update_visibility_grants(Context.t(), pos_integer(), %{
          optional(:add) => [grant()],
          optional(:remove) => [grant()]
        }) :: {:ok, [%ProjectVisibility{}]} | {:error, term()}
  def update_visibility_grants(%Context{} = context, project_id, changes)
      when is_integer(project_id) and is_map(changes) do
    to_add = Map.get(changes, :add, [])
    to_remove = Map.get(changes, :remove, [])

    with :ok <- valid_grants(to_add ++ to_remove) do
      Repo.transaction(fn ->
        with {:ok, project} <- lock_project(project_id),
             current = project_grants(project_id),
             {:ok, added} <- add_grants(project_id, Enum.uniq(to_add) -- Map.keys(current)),
             {:ok, removed} <- remove_grants(Map.take(current, Enum.uniq(to_remove))),
             :ok <- record_grants(context, project, "added", added),
             :ok <- record_grants(context, project, "removed", removed) do
          Repo.all(from(v in ProjectVisibility, where: v.project_id == ^project_id))
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
    end
  end

  def update_visibility_grants(_context, _project_id, _changes), do: {:error, :invalid_request}

  defp valid_grants(grants) do
    case Enum.all?(
           grants,
           &match?({kind, id} when kind in [:author, :institution] and is_integer(id), &1)
         ) do
      true -> :ok
      false -> {:error, :invalid_request}
    end
  end

  defp lock_project(project_id) do
    case Repo.one(from(p in Project, where: p.id == ^project_id, lock: "FOR NO KEY UPDATE")) do
      nil -> {:error, :not_found}
      project -> {:ok, project}
    end
  end

  defp project_grants(project_id) do
    from(v in ProjectVisibility, where: v.project_id == ^project_id)
    |> Repo.all()
    |> Enum.flat_map(fn
      %ProjectVisibility{author_id: id} = row when is_integer(id) ->
        [{{:author, id}, row}]

      %ProjectVisibility{institution_id: id} = row when is_integer(id) ->
        [{{:institution, id}, row}]

      _row ->
        []
    end)
    |> Map.new()
  end

  defp add_grants(project_id, grants) do
    Enum.reduce_while(grants, {:ok, []}, fn {kind, id} = grant, {:ok, added} ->
      attrs = %{project_id: project_id} |> Map.put(:"#{kind}_id", id)

      case %ProjectVisibility{} |> ProjectVisibility.changeset(attrs) |> Repo.insert() do
        {:ok, _row} -> {:cont, {:ok, [grant | added]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp remove_grants(rows) do
    Enum.reduce_while(rows, {:ok, []}, fn {grant, row}, {:ok, removed} ->
      case Repo.delete(row) do
        {:ok, _row} -> {:cont, {:ok, [grant | removed]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp record_grants(_context, _project, _operation, []), do: :ok

  defp record_grants(context, project, operation, grants) do
    side =
      case operation do
        "added" -> "after"
        "removed" -> "before"
      end

    values = grants |> Enum.sort() |> Enum.map(fn {kind, id} -> %{"#{kind}_id" => id} end)

    with {:ok, changeset} <-
           Auditing.build(context, %{
             event_type: :project_settings_changed,
             entity: {:project, project.id, project},
             scope: %{project_id: project.id},
             event_key: "project:#{project.id}:settings_changed",
             changes: %{"visibility_grants" => %{"operation" => operation, side => values}}
           }),
         {:ok, _event} <- Auditing.insert(changeset) do
      :ok
    end
  end
end
