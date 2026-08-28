defmodule Oli.Scenarios.Directives.Assert.LearningObjectivesAssertion do
  @moduledoc """
  Verifies learning objectives available in a course or container scope for a section.
  """

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Scenarios.DirectiveTypes.{AssertDirective, VerificationResult}
  alias Oli.Scenarios.Directives.Assert.Helpers

  @doc """
  Verifies that the configured objective titles are present or absent in the requested scope.
  """
  def assert(%AssertDirective{learning_objectives: spec}, state) when is_map(spec) do
    verification =
      with {:ok, section} <- Helpers.get_section(state, spec.section),
           {:ok, container_id} <- resolve_container_id(section.id, spec.container) do
        actual = objective_titles(section, container_id)
        missing = MapSet.difference(MapSet.new(spec.includes), actual)
        unexpected = MapSet.intersection(MapSet.new(spec.excludes), actual)

        verification(spec, actual, missing, unexpected)
      else
        {:error, reason} -> failed(spec, "Could not verify learning objectives: #{reason}", nil)
      end

    {:ok, state, verification}
  end

  def assert(%AssertDirective{learning_objectives: nil}, state), do: {:ok, state, nil}

  defp resolve_container_id(_section_id, container) when container in [nil, "course"],
    do: {:ok, nil}

  defp resolve_container_id(section_id, container) when is_binary(container) do
    case Enum.find(SectionResourceDepot.containers(section_id), &(&1.title == container)) do
      nil -> {:error, "Container '#{container}' not found in section"}
      section_resource -> {:ok, section_resource.resource_id}
    end
  end

  defp objective_titles(section, container_id) do
    section
    |> Sections.get_objectives_and_subobjectives(exclude_sub_objectives: false)
    |> Enum.filter(&(container_id in List.wrap(&1.container_ids)))
    |> Enum.map(&(Map.get(&1, :subobjective) || &1.objective))
    |> MapSet.new()
  end

  defp verification(spec, actual, missing, unexpected) do
    actual = actual |> MapSet.to_list() |> Enum.sort()

    if MapSet.size(missing) == 0 and MapSet.size(unexpected) == 0 do
      %VerificationResult{
        to: spec.section,
        passed: true,
        message: "Learning objectives match the expected scope",
        expected: expected(spec),
        actual: actual
      }
    else
      details =
        [
          set_message("missing", missing),
          set_message("unexpected", unexpected)
        ]
        |> Enum.reject(&is_nil/1)
        |> Enum.join("; ")

      failed(spec, "Learning objectives mismatch: #{details}", actual)
    end
  end

  defp set_message(label, set) do
    case set |> MapSet.to_list() |> Enum.sort() do
      [] -> nil
      values -> "#{label} #{inspect(values)}"
    end
  end

  defp failed(spec, message, actual) do
    %VerificationResult{
      to: spec.section,
      passed: false,
      message: message,
      expected: expected(spec),
      actual: actual
    }
  end

  defp expected(spec), do: %{includes: spec.includes, excludes: spec.excludes}
end
