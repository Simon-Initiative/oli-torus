defmodule Oli.Scenarios.Directives.Assert.InsightsAssertion do
  @moduledoc """
  Verifies authoring analytics through the same BrowseInsights interface used by the UI.
  """

  alias Oli.Analytics.Summary.{BrowseInsights, BrowseInsightsOptions}
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Resources.ResourceType
  alias Oli.Scenarios.Directives.Assert.Helpers
  alias Oli.Scenarios.DirectiveTypes.{AssertDirective, VerificationResult}

  @metrics [
    :num_correct,
    :num_attempts,
    :num_hints,
    :num_first_attempts,
    :num_first_attempts_correct,
    :eventually_correct,
    :first_attempt_correct,
    :relative_difficulty
  ]

  @rate_metrics [:eventually_correct, :first_attempt_correct, :relative_difficulty]

  @doc """
  Verifies the configured insight metrics and returns a scenario verification result.
  """
  def assert(%AssertDirective{insights: spec}, state) when is_map(spec) do
    verification =
      with {:ok, built_project} <- Helpers.get_project(state, spec.project),
           {:ok, section_ids} <- resolve_section_ids(state, spec.sections),
           {:ok, target} <- resolve_target(state, built_project, spec),
           rows <- browse(built_project.project.id, section_ids, spec.resource_type, target),
           matches <- matching_rows(rows, target),
           {:ok, verification} <- verify_matches(spec, target, matches) do
        verification
      else
        {:error, reason} -> failed(spec, "Could not verify insights: #{reason}", nil)
      end

    {:ok, state, verification}
  end

  def assert(%AssertDirective{insights: nil}, state), do: {:ok, state, nil}

  defp resolve_section_ids(state, section_names) do
    Enum.reduce_while(section_names, {:ok, []}, fn section_name, {:ok, ids} ->
      case Helpers.get_section(state, section_name) do
        {:ok, section} -> {:cont, {:ok, [section.id | ids]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, ids} -> {:ok, Enum.reverse(ids)}
      error -> error
    end
  end

  defp resolve_target(_state, built_project, %{resource_type: :page, page: title}) do
    case Map.get(built_project.rev_by_title, title) do
      nil -> {:error, "Page '#{title}' not found in project"}
      revision -> {:ok, %{kind: :page, label: title, resource_id: revision.resource_id}}
    end
  end

  defp resolve_target(state, _built_project, %{
         project: project_name,
         resource_type: :activity,
         activity_virtual_id: virtual_id,
         part_id: part_id
       }) do
    case Map.get(state.activity_virtual_ids, {project_name, virtual_id}) do
      nil ->
        {:error, "Activity virtual_id '#{virtual_id}' not found in project"}

      revision ->
        {:ok,
         %{
           kind: :activity,
           label: virtual_id,
           resource_id: revision.resource_id,
           part_id: part_id
         }}
    end
  end

  defp resolve_target(_state, built_project, %{resource_type: :objective, objective: title}) do
    case Map.get(built_project.objectives_by_title || %{}, title) do
      nil -> {:error, "Objective '#{title}' not found in project"}
      revision -> {:ok, %{kind: :objective, label: title, resource_id: revision.resource_id}}
    end
  end

  defp browse(project_id, section_ids, resource_type, target) do
    BrowseInsights.browse_insights(
      %Paging{offset: 0, limit: 2},
      %Sorting{direction: :asc, field: :title},
      %BrowseInsightsOptions{
        project_id: project_id,
        section_ids: section_ids,
        resource_type_id: resource_type_id(resource_type),
        resource_id: target.resource_id,
        part_id: Map.get(target, :part_id)
      }
    )
  end

  defp resource_type_id(:page), do: ResourceType.id_for_page()
  defp resource_type_id(:activity), do: ResourceType.id_for_activity()
  defp resource_type_id(:objective), do: ResourceType.id_for_objective()

  defp matching_rows(rows, %{kind: :activity, resource_id: resource_id, part_id: part_id})
       when is_binary(part_id) do
    Enum.filter(rows, &(&1.resource_id == resource_id and &1.part_id == part_id))
  end

  defp matching_rows(rows, %{resource_id: resource_id}) do
    Enum.filter(rows, &(&1.resource_id == resource_id))
  end

  defp verify_matches(%{exists: false} = spec, target, []) do
    {:ok,
     passed(
       spec,
       "#{target_name(target)} has no insights row as expected",
       nil
     )}
  end

  defp verify_matches(%{exists: false} = spec, target, matches) do
    {:ok,
     failed(
       spec,
       "#{target_name(target)} has an insights row but was expected to have none",
       Enum.map(matches, &actual_metrics/1)
     )}
  end

  defp verify_matches(spec, target, []) do
    {:ok, failed(spec, "#{target_name(target)} insights row was not found", nil)}
  end

  defp verify_matches(spec, target, [row]) do
    mismatches = metric_mismatches(spec.expected, row, spec.tolerance)

    case mismatches do
      [] ->
        {:ok,
         passed(
           spec,
           "#{target_name(target)} insights match expected metrics",
           actual_metrics(row)
         )}

      mismatches ->
        details =
          Enum.map_join(mismatches, "; ", fn {metric, expected, actual} ->
            "#{metric} expected #{inspect(expected)}, got #{inspect(actual)}"
          end)

        {:ok,
         failed(
           spec,
           "#{target_name(target)} insights mismatch: #{details}",
           actual_metrics(row)
         )}
    end
  end

  defp verify_matches(spec, target, rows) do
    message =
      "#{target_name(target)} matched #{length(rows)} insights rows; specify part_id to select one"

    {:ok, failed(spec, message, Enum.map(rows, &actual_metrics/1))}
  end

  defp metric_mismatches(expected, row, tolerance) do
    Enum.reduce(expected, [], fn {metric, expected_value}, mismatches ->
      actual = Map.get(row, metric)

      if metric_matches?(metric, expected_value, actual, tolerance) do
        mismatches
      else
        [{metric, expected_value, actual} | mismatches]
      end
    end)
    |> Enum.reverse()
  end

  defp metric_matches?(metric, expected, actual, tolerance)
       when metric in @rate_metrics and is_number(expected) and is_number(actual),
       do: abs(expected - actual) <= tolerance

  defp metric_matches?(_metric, expected, actual, _tolerance), do: expected == actual

  defp actual_metrics(row), do: Map.take(row, @metrics)

  defp target_name(%{kind: kind, label: label}) do
    "#{kind |> Atom.to_string() |> String.capitalize()} '#{label}'"
  end

  defp passed(spec, message, actual) do
    %VerificationResult{
      to: spec.project,
      passed: true,
      message: message,
      expected: spec.expected,
      actual: actual
    }
  end

  defp failed(spec, message, actual) do
    %VerificationResult{
      to: spec.project,
      passed: false,
      message: message,
      expected: spec.expected,
      actual: actual
    }
  end
end
