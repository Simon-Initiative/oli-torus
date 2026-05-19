defmodule Oli.Scenarios.Directives.Assert.GradebookAssertion do
  @moduledoc """
  Handles instructor-facing gradebook assertions.
  """

  alias Oli.Grading
  alias Oli.Scenarios.DirectiveTypes.{AssertDirective, VerificationResult}
  alias Oli.Scenarios.Directives.Assert.Helpers

  def assert(%AssertDirective{gradebook: gradebook_spec}, state) when is_map(gradebook_spec) do
    with {:ok, _instructor} <- Helpers.get_user(state, gradebook_spec.instructor),
         {:ok, section} <- Helpers.get_section(state, gradebook_spec.section),
         {:ok, student} <- Helpers.get_user(state, gradebook_spec.student),
         {:ok, resource_id} <- get_resource_id(state, section, gradebook_spec.page),
         {:ok, gradebook_score} <-
           fetch_gradebook_score(section.id, student.id, resource_id, gradebook_spec.page) do
      verification =
        verify_gradebook_score(
          gradebook_spec.section,
          gradebook_spec.student,
          gradebook_spec.page,
          gradebook_spec,
          gradebook_score
        )

      {:ok, state, verification}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  def assert(%AssertDirective{gradebook: nil}, state), do: {:ok, state, nil}

  defp fetch_gradebook_score(section_id, student_id, resource_id, page_title) do
    case Grading.get_gradebook_score_for_student_and_resource(section_id, student_id, resource_id) do
      nil -> {:error, "No gradebook score found for page '#{page_title}'"}
      score -> {:ok, score}
    end
  end

  defp verify_gradebook_score(section_name, student_name, page_title, expected, actual) do
    try do
      assert_equal(:score, expected.score, actual.score)
      assert_equal(:out_of, expected.out_of, actual.out_of)
      assert_equal(:was_late, expected.was_late, actual.was_late)

      %VerificationResult{
        to: section_name,
        passed: true,
        message:
          "Gradebook entry for student '#{student_name}' on '#{page_title}' matches expected"
      }
    rescue
      e ->
        %VerificationResult{
          to: section_name,
          passed: false,
          message: Exception.message(e)
        }
    end
  end

  defp assert_equal(_field, nil, _actual), do: :ok

  defp assert_equal(field, expected, actual) when expected != actual do
    raise "Gradebook field '#{field}' mismatch: expected #{inspect(expected)}, got #{inspect(actual)}"
  end

  defp assert_equal(_field, _expected, _actual), do: :ok

  defp get_resource_id(state, section, page_title) do
    case get_page_revision(state, section, page_title) do
      {:ok, revision} -> {:ok, revision.resource_id}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_page_revision(state, section, page_title) do
    project =
      state.projects
      |> Map.values()
      |> Enum.find(fn built_project ->
        built_project.project.id == section.base_project_id
      end)

    case project do
      nil ->
        {:error, "Source project for section not found"}

      built_project ->
        case Map.get(built_project.rev_by_title, page_title) do
          nil -> {:error, "Page '#{page_title}' not found in project"}
          revision -> {:ok, revision}
        end
    end
  end
end
