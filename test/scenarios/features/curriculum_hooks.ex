defmodule Oli.Scenarios.Features.CurriculumHooks do
  @moduledoc """
  Scenario hooks that intentionally corrupt curriculum hierarchy data to exercise
  authoring operations against malformed inputs.
  """

  alias Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  import ExUnit.Assertions

  alias Oli.Publishing.AuthoringResolver
  alias Oli.Repo
  alias Oli.Resources.{Resource, ResourceType, Revision}
  alias Oli.Scenarios.DirectiveTypes.ExecutionState
  alias Oli.Scenarios.Engine

  require Logger

  @doc """
  Replaces the first child's resource id within a container with `nil`.

  Intended to surface code paths that must tolerate unexpected `nil` entries in
  `revision.children` arrays.
  """
  def replace_child_with_nil(%ExecutionState{} = state) do
    mutate_first_container_child(state, "replace child resource id with nil", fn children ->
      case children do
        [] ->
          {:error, :no_children}

        [_ | _] = current_children ->
          {:ok, List.replace_at(current_children, 0, nil)}
      end
    end)
  end

  @doc """
  Replaces the first child's resource id with a value that does not correspond to
  any existing resource.
  """
  def replace_child_with_nonexistent_id(%ExecutionState{} = state) do
    mutate_first_container_child(
      state,
      "replace child with nonexistent resource id",
      fn children ->
        case children do
          [] ->
            {:error, :no_children}

          [_ | _] = current_children ->
            {:ok, List.replace_at(current_children, 0, generate_missing_resource_id())}
        end
      end
    )
  end

  @doc """
  Validates that curriculum operations completed successfully after the
  `replace_child_with_nil/1` hook was applied.
  Ensures the mutated container still contains the nil entry (to prove we did
  not auto-heal the data) while confirming new authoring actions produced the
  expected structure.
  """
  def assert_nil_child_outcome(%ExecutionState{} = state) do
    with {:ok, _project_name, built_project} <- select_project(state),
         {:ok, unit_revision} <- fetch_revision_by_title(built_project, "Unit 1"),
         {:ok, root_revision} <- fetch_root_revision(built_project) do
      statuses = child_statuses(built_project.project.slug, unit_revision.children)
      root_statuses = child_statuses(built_project.project.slug, root_revision.children)

      assert Enum.any?(statuses, &match?({nil, _}, &1)),
             "Expected Unit 1 children to retain a nil entry"

      assert titles_from_statuses(statuses) == ["Page B", "Resilient Page"],
             "Unexpected Unit 1 children after operations: #{inspect(statuses)}"

      assert titles_from_statuses(root_statuses) == ["Unit 1", "Unit 2", "Unit 3"],
             "Unexpected root children after operations: #{inspect(root_statuses)}"

      state
    else
      {:error, reason} ->
        flunk("Nil child outcome verification failed: #{inspect(reason)}")
    end
  end

  @doc """
  Validates that curriculum operations completed successfully after the
  `replace_child_with_nonexistent_id/1` hook was applied.
  Confirms the bogus id remains (to show robustness) and that reorder/add
  operations still produced the desired ordering of legitimate pages.
  """
  def assert_missing_child_outcome(%ExecutionState{} = state) do
    with {:ok, _project_name, built_project} <- select_project(state),
         {:ok, unit_revision} <- fetch_revision_by_title(built_project, "Unit 1"),
         {:ok, root_revision} <- fetch_root_revision(built_project) do
      statuses = child_statuses(built_project.project.slug, unit_revision.children)
      root_statuses = child_statuses(built_project.project.slug, root_revision.children)

      assert Enum.any?(statuses, &match?({:missing, _}, &1)),
             "Expected Unit 1 children to retain a missing resource id entry"

      assert titles_from_statuses(statuses) == ["Recovered Page", "Page B"],
             "Unexpected Unit 1 children after operations: #{inspect(statuses)}"

      assert titles_from_statuses(root_statuses) == ["Unit 1", "Unit 2"],
             "Unexpected root children after operations: #{inspect(root_statuses)}"

      state
    else
      {:error, reason} ->
        flunk("Missing child outcome verification failed: #{inspect(reason)}")
    end
  end

  defp mutate_first_container_child(%ExecutionState{} = state, action, transformer) do
    with {:ok, project_name, built_project} <- select_project(state),
         {:ok, container_title, container_revision} <- select_primary_container(built_project),
         {:ok, mutated_children} <- transformer.(container_revision.children || []),
         {:ok, refreshed_revision} <-
           persist_children(built_project.project.slug, container_revision, mutated_children),
         {:ok, updated_project} <-
           refresh_project(built_project, container_title, refreshed_revision) do
      Logger.info("Scenario hook #{inspect(__MODULE__)}: #{action} in #{container_title}")

      Engine.put_project(state, project_name, updated_project)
    else
      {:error, reason} ->
        Logger.warning(
          "Scenario hook #{inspect(__MODULE__)} failed to #{action}: #{inspect(reason)}"
        )

        state
    end
  end

  defp select_project(%ExecutionState{projects: projects}) when map_size(projects) >= 1 do
    {name, built_project} = Enum.at(projects, 0)
    {:ok, name, built_project}
  end

  defp select_project(_state), do: {:error, :no_projects}

  defp select_primary_container(built_project) do
    candidate =
      built_project.rev_by_title
      |> Enum.find(fn {_title, revision} ->
        revision.resource_type_id == ResourceType.id_for_container() &&
          revision.resource_id != built_project.root.revision.resource_id
      end)

    case candidate do
      nil ->
        {:ok, root_title(built_project), built_project.root.revision}

      {title, revision} ->
        {:ok, title, revision}
    end
  end

  defp fetch_revision_by_title(built_project, title) do
    cond do
      title == root_title(built_project) ->
        fetch_root_revision(built_project)

      true ->
        case Map.get(built_project.id_by_title, title) do
          nil -> {:error, {:unknown_title, title}}
          resource_id -> fresh_revision(built_project.project.slug, resource_id)
        end
    end
  end

  defp fetch_root_revision(built_project) do
    fresh_revision(built_project.project.slug, built_project.root.revision.resource_id)
  end

  defp fresh_revision(project_slug, resource_id) when is_integer(resource_id) do
    case AuthoringResolver.from_resource_id(project_slug, resource_id) do
      nil -> {:error, {:revision_not_found, resource_id}}
      revision -> {:ok, revision}
    end
  end

  defp fresh_revision(_project_slug, nil), do: {:error, :nil_resource_id}

  defp persist_children(project_slug, %Revision{} = revision, children) do
    Repo.transaction(fn ->
      revision
      |> Changeset.change(%{children: children})
      |> Repo.update!()
    end)
    |> case do
      {:ok, _updated_revision} ->
        {:ok, AuthoringResolver.from_resource_id(project_slug, revision.resource_id)}

      {:error, error} ->
        {:error, error}
    end
  end

  defp refresh_project(built_project, title, %Revision{} = updated_revision) do
    updated_rev_by_title = Map.put(built_project.rev_by_title, title, updated_revision)

    {updated_rev_by_title, updated_root} =
      if root_revision?(built_project, updated_revision) || title == root_title(built_project) do
        {
          Map.put(updated_rev_by_title, "root", updated_revision),
          %{built_project.root | revision: updated_revision}
        }
      else
        {updated_rev_by_title, built_project.root}
      end

    {:ok, %{built_project | rev_by_title: updated_rev_by_title, root: updated_root}}
  end

  defp root_revision?(built_project, %Revision{} = revision) do
    built_project.root.revision.resource_id == revision.resource_id
  end

  defp root_title(built_project), do: built_project.root.revision.title

  defp generate_missing_resource_id do
    current_max = Repo.one(from r in Resource, select: max(r.id)) || 0
    current_max + 1_000_000
  end

  defp child_statuses(project_slug, children) do
    Enum.map(children || [], fn
      nil ->
        {nil, nil}

      resource_id ->
        case AuthoringResolver.from_resource_id(project_slug, resource_id) do
          nil -> {:missing, resource_id}
          revision -> {:ok, revision.title}
        end
    end)
  end

  defp titles_from_statuses(statuses) do
    statuses
    |> Enum.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, title} -> title end)
  end
end
