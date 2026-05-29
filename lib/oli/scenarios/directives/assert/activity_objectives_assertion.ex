defmodule Oli.Scenarios.Directives.Assert.ActivityObjectivesAssertion do
  @moduledoc """
  Verifies objective titles attached to a scenario-created activity.
  """

  alias Oli.Publishing.AuthoringResolver
  alias Oli.Scenarios.Engine
  alias Oli.Scenarios.DirectiveTypes.{AssertDirective, VerificationResult}

  def assert(%AssertDirective{activity_objectives: spec}, state) when is_map(spec) do
    result =
      with {:ok, built_project} <- get_project(state, spec.project),
           {:ok, activity_revision} <- get_activity(state, spec.project, spec.activity_virtual_id),
           {:ok, fresh_activity} <- get_fresh_activity(built_project, activity_revision),
           actual <- objective_titles(fresh_activity.objectives, built_project),
           expected <- Enum.sort(spec.expected || []) do
        if actual == expected do
          passed(spec.project, spec.activity_virtual_id, expected, actual)
        else
          failed(spec.project, spec.activity_virtual_id, expected, actual)
        end
      else
        {:error, reason} ->
          %VerificationResult{
            to: spec.project,
            passed: false,
            message:
              "Could not verify activity objectives for '#{spec.activity_virtual_id}': #{reason}",
            expected: spec.expected || [],
            actual: nil
          }
      end

    {:ok, state, result}
  end

  def assert(%AssertDirective{activity_objectives: nil}, state), do: {:ok, state, nil}

  defp get_project(state, project_name) do
    case Engine.get_project(state, project_name) do
      nil -> {:error, "Project '#{project_name}' not found"}
      built_project -> {:ok, built_project}
    end
  end

  defp get_activity(state, project_name, virtual_id) do
    case Map.get(state.activity_virtual_ids, {project_name, virtual_id}) do
      nil -> {:error, "Activity virtual_id '#{virtual_id}' not found"}
      revision -> {:ok, revision}
    end
  end

  defp get_fresh_activity(built_project, activity_revision) do
    case AuthoringResolver.from_resource_id(
           built_project.project.slug,
           activity_revision.resource_id
         ) do
      nil -> {:error, "Activity revision '#{activity_revision.resource_id}' not found"}
      fresh_activity -> {:ok, fresh_activity}
    end
  end

  defp objective_titles(objectives, built_project) when is_map(objectives) do
    id_to_title =
      (built_project.objectives_by_title || %{})
      |> Enum.map(fn {title, revision} -> {revision.resource_id, title} end)
      |> Map.new()

    objectives
    |> Map.values()
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.map(&Map.get(id_to_title, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.sort()
  end

  defp objective_titles(_objectives, _built_project), do: []

  defp passed(project, virtual_id, expected, actual) do
    %VerificationResult{
      to: project,
      passed: true,
      message: "Activity '#{virtual_id}' has expected learning objectives",
      expected: expected,
      actual: actual
    }
  end

  defp failed(project, virtual_id, expected, actual) do
    %VerificationResult{
      to: project,
      passed: false,
      message:
        "Activity '#{virtual_id}' learning objectives mismatch: expected #{inspect(expected)}, got #{inspect(actual)}",
      expected: expected,
      actual: actual
    }
  end
end
