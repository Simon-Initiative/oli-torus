defmodule Oli.Scenarios.Directives.ActivityAttemptSupport do
  @moduledoc """
  Shared lookup and normalization helpers for scenario learner activity actions.
  """

  alias Oli.Scenarios.Directives.AttemptSupport
  alias Oli.Scenarios.DirectiveTypes.ExecutionState

  @doc """
  Returns the active page attempt state for a student, section, and page.
  """
  def get_attempt_state(
        %ExecutionState{} = state,
        student_name,
        section_name,
        page_title
      ) do
    key = {student_name, section_name, page_title}

    case Map.get(state.page_attempts, key) do
      nil ->
        {:error, "No attempt found - student must view page first"}

      {:not_started, _} ->
        {:error, "Page not started - cannot answer questions"}

      {_status, attempt_state} ->
        {:ok, attempt_state}
    end
  end

  @doc """
  Resolves a scenario activity revision by its section's project and virtual ID.
  """
  def get_activity_revision(%ExecutionState{} = state, section_name, activity_virtual_id) do
    with {:ok, section} <- AttemptSupport.get_section(state, section_name),
         {:ok, project_name} <- project_name_for_section(state, section) do
      fetch_activity_revision(state, project_name, activity_virtual_id)
    end
  end

  @doc """
  Finds and normalizes an activity attempt from a page attempt hierarchy.
  """
  def find_activity_attempt(attempt_state, activity_revision) do
    case Map.get(attempt_state.attempt_hierarchy, activity_revision.resource_id) do
      nil ->
        find_activity_by_resource_id(attempt_state, activity_revision.resource_id)

      attempt ->
        normalize_activity_attempt(attempt)
    end
  end

  @doc """
  Selects a part attempt, requiring `part_id` when the activity has multiple parts.
  """
  def find_part_attempt(%{activity_attempt: %{part_attempts: part_attempts}}, part_id)
      when is_list(part_attempts) do
    case {part_id, part_attempts} do
      {nil, [part_attempt]} ->
        {:ok, part_attempt}

      {nil, []} ->
        {:error, "Could not find part attempt"}

      {nil, _multiple} ->
        {:error, "Activity has multiple parts; request_hint must specify part_id"}

      {part_id, part_attempts} ->
        case Enum.find(part_attempts, &(&1.part_id == part_id)) do
          nil -> {:error, "Part '#{part_id}' not found in activity attempt"}
          part_attempt -> {:ok, part_attempt}
        end
    end
  end

  def find_part_attempt(_activity_attempt_info, _part_id),
    do: {:error, "Could not find part attempt"}

  defp find_activity_by_resource_id(attempt_state, resource_id) do
    matching_attempts =
      attempt_state.attempt_hierarchy
      |> Map.values()
      |> Enum.filter(fn
        {%{revision: %{resource_id: ^resource_id}}, _part_attempts} -> true
        %{revision: %{resource_id: ^resource_id}} -> true
        _ -> false
      end)

    case matching_attempts do
      [attempt] -> normalize_activity_attempt(attempt)
      [] -> {:error, "Could not find activity attempt for resource_id #{resource_id}"}
      _ -> {:error, "Multiple activity attempts matched resource_id #{resource_id}"}
    end
  end

  defp project_name_for_section(state, section) do
    project_name =
      Enum.find_value(state.projects, fn
        {project_name, %{project: %{id: project_id}}}
        when project_id == section.base_project_id ->
          project_name

        _ ->
          nil
      end)

    case project_name do
      nil -> {:error, "Source project for section '#{section.slug}' not found"}
      project_name -> {:ok, project_name}
    end
  end

  defp fetch_activity_revision(state, project_name, activity_virtual_id) do
    case Map.get(state.activity_virtual_ids, {project_name, activity_virtual_id}) do
      nil ->
        {:error,
         "Activity with virtual_id '#{activity_virtual_id}' not found in project '#{project_name}'"}

      revision ->
        {:ok, revision}
    end
  end

  defp normalize_activity_attempt({%{attempt_guid: guid} = activity_attempt, part_attempts}) do
    activity_attempt_with_parts = %{
      activity_attempt
      | part_attempts: Map.values(part_attempts)
    }

    {:ok, %{attempt_guid: guid, activity_attempt: activity_attempt_with_parts}}
  end

  defp normalize_activity_attempt(%{attemptGuid: guid} = thin_info),
    do: {:ok, %{attempt_guid: guid, activity_attempt: thin_info}}

  defp normalize_activity_attempt(_), do: {:error, "Unexpected attempt hierarchy format"}
end
