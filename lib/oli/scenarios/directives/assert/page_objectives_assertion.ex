defmodule Oli.Scenarios.Directives.Assert.PageObjectivesAssertion do
  @moduledoc """
  Verifies the learning objective titles attached to a published delivery page.
  """

  alias Oli.Publishing.DeliveryResolver
  alias Oli.Scenarios.DirectiveTypes.{AssertDirective, VerificationResult}
  alias Oli.Scenarios.Directives.AttemptSupport

  def assert(%AssertDirective{page_objectives: spec}, state) when is_map(spec) do
    result =
      with {:ok, section} <- AttemptSupport.get_section(state, spec.section),
           {:ok, page_revision} <-
             AttemptSupport.get_page_revision(state, spec.section, spec.page) do
        actual =
          (page_revision.objectives || %{})
          |> Map.get("attached", [])
          |> DeliveryResolver.objectives_by_resource_ids(section.slug)
          |> Enum.map(& &1.title)
          |> Enum.sort()

        expected = Enum.sort(spec.expected || [])

        if actual == expected do
          passed(spec.section, spec.page, expected, actual)
        else
          failed(spec.section, spec.page, expected, actual)
        end
      else
        {:error, reason} ->
          %VerificationResult{
            to: spec.section,
            passed: false,
            message: "Could not verify page objectives for '#{spec.page}': #{inspect(reason)}",
            expected: spec.expected || [],
            actual: nil
          }
      end

    {:ok, state, result}
  end

  def assert(%AssertDirective{page_objectives: nil}, state), do: {:ok, state, nil}

  defp passed(section, page, expected, actual) do
    %VerificationResult{
      to: section,
      passed: true,
      message: "Page '#{page}' has expected learning objectives",
      expected: expected,
      actual: actual
    }
  end

  defp failed(section, page, expected, actual) do
    %VerificationResult{
      to: section,
      passed: false,
      message:
        "Page '#{page}' learning objectives mismatch: expected #{inspect(expected)}, got #{inspect(actual)}",
      expected: expected,
      actual: actual
    }
  end
end
