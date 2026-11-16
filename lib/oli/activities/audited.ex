defmodule Oli.Activities.Audited do
  @moduledoc """
  Application boundary for audited changes to the activities and tools available in a project.

  The activities enabled in a project are recorded as the `enabled_activities` of
  `project_settings_changed`: one event for the activities that became available, with
  operation `added`, and one for those that stopped being available, with operation `removed`.
  Each entry carries the activity registration ID and its title. A call that changes nothing
  records no event.

  Commands do not authorize the actor; callers keep their existing authorization.
  """

  # This configuration is what makes CI fail when a caller bypasses this facade.
  # Keep the boundary top-level and never export internal modules. Outgoing checks are off
  # because this boundary calls into Oli, which depends on it; incoming checks stay on.
  use Boundary, top_level?: true, exports: [], check: [out: false]

  import Ecto.Query, only: [from: 2]

  alias Oli.Activities.{ActivityRegistration, ActivityRegistrationProject}
  alias Oli.Auditing
  alias Oli.Auditing.Context
  alias Oli.Authoring.Course.Project
  alias Oli.Repo

  @doc """
  Makes the activities in `:add` available in the project with ID `project_id` and removes
  those in `:remove`, in one transaction. Activity IDs are registration IDs. Returns `:ok`.
  """
  @spec update_project_activities(Context.t(), pos_integer(), %{
          optional(:add) => [pos_integer()],
          optional(:remove) => [pos_integer()]
        }) :: :ok | {:error, term()}
  def update_project_activities(%Context{} = context, project_id, changes)
      when is_integer(project_id) and is_map(changes) do
    to_add = Map.get(changes, :add, [])
    to_remove = Map.get(changes, :remove, [])

    change_availability(context, project_id, fn ->
      upsert_enabled(project_id, to_add)
      delete_registrations(project_id, to_remove)
      :ok
    end)
  end

  def update_project_activities(_context, _project_id, _changes), do: {:error, :invalid_request}

  @doc """
  Enables or disables an activity the project already lists. Returns `{:error, message}` when the
  project does not list the activity, as before.
  """
  @spec set_project_activity_status(
          Context.t(),
          pos_integer(),
          pos_integer(),
          :enabled | :disabled
        ) :: :ok | {:error, term()}
  def set_project_activity_status(%Context{} = context, project_id, activity_id, status)
      when is_integer(project_id) and is_integer(activity_id) and
             status in [:enabled, :disabled] do
    change_availability(context, project_id, fn ->
      {count, _} =
        from(arp in ActivityRegistrationProject,
          where: arp.project_id == ^project_id and arp.activity_registration_id == ^activity_id
        )
        |> Repo.update_all(set: [status: status, updated_at: NaiveDateTime.utc_now()])

      case count do
        0 -> {:error, "No ActivityRegistrationProject found"}
        _ -> :ok
      end
    end)
  end

  def set_project_activity_status(_context, _project_id, _activity_id, _status),
    do: {:error, :invalid_request}

  defp change_availability(context, project_id, write) do
    Repo.transaction(fn ->
      with {:ok, project} <- lock_project(project_id),
           before = enabled(project_id),
           :ok <- write.(),
           after_state = enabled(project_id),
           :ok <- record(context, project, "added", Map.drop(after_state, Map.keys(before))),
           :ok <- record(context, project, "removed", Map.drop(before, Map.keys(after_state))) do
        :ok
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, :ok} -> :ok
      error -> error
    end
  end

  defp lock_project(project_id) do
    case Repo.one(from(p in Project, where: p.id == ^project_id, lock: "FOR NO KEY UPDATE")) do
      nil -> {:error, :not_found}
      project -> {:ok, project}
    end
  end

  # Activities available in the project, by registration ID, with their titles.
  defp enabled(project_id) do
    from(arp in ActivityRegistrationProject,
      join: ar in ActivityRegistration,
      on: ar.id == arp.activity_registration_id,
      where: arp.project_id == ^project_id and arp.status == :enabled,
      select: {ar.id, ar.title}
    )
    |> Repo.all()
    |> Map.new()
  end

  defp upsert_enabled(_project_id, []), do: :ok

  defp upsert_enabled(project_id, activity_ids) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    values =
      Enum.map(activity_ids, fn activity_id ->
        %{
          activity_registration_id: activity_id,
          project_id: project_id,
          status: :enabled,
          inserted_at: now,
          updated_at: now
        }
      end)

    Repo.insert_all(ActivityRegistrationProject, values,
      on_conflict: [set: [status: :enabled, updated_at: now]],
      conflict_target: [:activity_registration_id, :project_id]
    )

    :ok
  end

  defp delete_registrations(_project_id, []), do: :ok

  defp delete_registrations(project_id, activity_ids) do
    from(arp in ActivityRegistrationProject,
      where: arp.project_id == ^project_id and arp.activity_registration_id in ^activity_ids
    )
    |> Repo.delete_all()

    :ok
  end

  defp record(_context, _project, _operation, activities) when map_size(activities) == 0,
    do: :ok

  defp record(context, project, operation, activities) do
    entries =
      activities
      |> Enum.sort()
      |> Enum.map(fn {id, title} -> %{"activity_registration_id" => id, "title" => title} end)

    side =
      case operation do
        "added" -> "after"
        "removed" -> "before"
      end

    with {:ok, changeset} <-
           Auditing.build(context, %{
             event_type: :project_settings_changed,
             entity: {:project, project.id, project},
             scope: %{project_id: project.id},
             event_key: "project:#{project.id}:settings_changed",
             changes: %{"enabled_activities" => %{"operation" => operation, side => entries}}
           }),
         {:ok, _event} <- Auditing.insert(changeset) do
      :ok
    end
  end
end
