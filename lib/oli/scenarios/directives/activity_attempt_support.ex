defmodule Oli.Scenarios.Directives.ActivityAttemptSupport do
  @moduledoc false

  alias Oli.Scenarios.DirectiveTypes.ExecutionState

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

  def get_activity_revision(%ExecutionState{} = state, activity_virtual_id) do
    activity_revision =
      Enum.find_value(state.activity_virtual_ids, fn
        {{_project_name, ^activity_virtual_id}, revision} -> revision
        _ -> nil
      end)

    case activity_revision do
      nil -> {:error, "Activity with virtual_id '#{activity_virtual_id}' not found"}
      revision -> {:ok, revision}
    end
  end

  def find_activity_attempt(attempt_state, activity_revision) do
    case Map.get(attempt_state.attempt_hierarchy, activity_revision.resource_id) do
      nil ->
        find_activity_by_content(attempt_state, activity_revision)

      attempt ->
        normalize_activity_attempt(attempt)
    end
  end

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

  defp find_activity_by_content(attempt_state, activity_revision) do
    activity_type = activity_type(activity_revision.content)

    matching_attempt =
      attempt_state.attempt_hierarchy
      |> Map.values()
      |> Enum.find(fn
        {%{revision: %{content: content}}, _} -> activity_type(content) == activity_type
        %{revision: %{content: content}} -> activity_type(content) == activity_type
        _ -> false
      end)

    case matching_attempt do
      nil -> find_single_activity_attempt(attempt_state, activity_type)
      attempt -> normalize_activity_attempt(attempt)
    end
  end

  defp find_single_activity_attempt(attempt_state, activity_type) do
    case Map.values(attempt_state.attempt_hierarchy) do
      [attempt] -> normalize_activity_attempt(attempt)
      [] -> {:error, "No activity attempts found in hierarchy"}
      _ -> {:error, "Could not find matching activity attempt for type: #{activity_type}"}
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

  defp activity_type(content), do: content["activityType"] || content["type"]
end
