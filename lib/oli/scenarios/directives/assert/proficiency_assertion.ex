defmodule Oli.Scenarios.Directives.Assert.ProficiencyAssertion do
  @moduledoc """
  Handles proficiency assertions for learning objectives.

  Proficiency assertions check the calculated proficiency values for learning objectives
  within a section. They can be student-specific or calculate average proficiency across
  all enrolled students.
  """

  alias Oli.Scenarios.DirectiveTypes.{AssertDirective, VerificationResult}
  alias Oli.Scenarios.Engine
  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Sections
  alias Oli.Resources
  alias Oli.Repo

  @doc """
  Asserts proficiency for a learning objective.

  The proficiency assertion checks:
  - The proficiency bucket (High/Medium/Low/Not enough data)
  - Optionally, the raw proficiency value (0.0-1.0)

  Can be scoped to:
  - A specific student or all students
  - A specific page or container
  """
  def assert(%AssertDirective{proficiency: proficiency}, state) when is_map(proficiency) do
    with {:ok, section} <- get_section(state, proficiency.section),
         {:ok, objective} <- find_objective_by_title(state, proficiency.objective),
         {:ok, actual_proficiency} <-
           calculate_proficiency(
             section,
             objective,
             state,
             proficiency
           ) do
      {actual_value, actual_bucket} = actual_proficiency
      expected_bucket = proficiency.bucket
      expected_value = proficiency.value

      # Check if the bucket matches
      bucket_matches = actual_bucket == expected_bucket

      # Check if the value matches (if specified)
      value_matches =
        if expected_value do
          # Round to 2 decimal places for comparison
          Float.round(actual_value || 0.0, 2) == Float.round(expected_value, 2)
        else
          true
        end

      passed = bucket_matches && value_matches

      message =
        if passed do
          "Proficiency assertion passed: bucket=#{actual_bucket}, value=#{format_value(actual_value)}"
        else
          parts = []

          parts =
            if !bucket_matches do
              ["Expected bucket '#{expected_bucket}' but got '#{actual_bucket}'"] ++ parts
            else
              parts
            end

          parts =
            if expected_value && !value_matches do
              ["Expected value #{expected_value} but got #{format_value(actual_value)}"] ++ parts
            else
              parts
            end

          Enum.join(parts, "; ")
        end

      verification = %VerificationResult{
        passed: passed,
        message: message,
        to: proficiency.section,
        expected: %{bucket: expected_bucket, value: expected_value},
        actual: %{bucket: actual_bucket, value: actual_value}
      }

      {:ok, state, verification}
    else
      {:error, reason} ->
        verification = %VerificationResult{
          passed: false,
          message: "Proficiency assertion failed: #{reason}",
          to: proficiency.section,
          expected: nil,
          actual: nil
        }

        {:ok, state, verification}
    end
  end

  defp get_section(state, section_name) do
    case Engine.get_section(state, section_name) do
      nil -> {:error, "Section '#{section_name}' not found"}
      section -> {:ok, section}
    end
  end

  defp find_objective_by_title(state, objective_title) do
    # Search through all projects for an objective with the given title
    objective =
      state.projects
      |> Enum.flat_map(fn {_name, project} ->
        # BuiltProject stores objectives in objectives_by_title
        case Map.get(project, :objectives_by_title) do
          nil ->
            []

          objectives_map when is_map(objectives_map) ->
            # objectives_by_title is a map of title -> objective
            case Map.get(objectives_map, objective_title) do
              nil -> []
              obj -> [obj]
            end
        end
      end)
      |> List.first()

    case objective do
      nil -> {:error, "Learning objective '#{objective_title}' not found"}
      obj -> {:ok, obj}
    end
  end

  defp calculate_proficiency(section, objective, state, proficiency) do
    cond do
      # Student-specific proficiency for a learning objective
      proficiency.student != nil ->
        calculate_student_proficiency(section, objective, state, proficiency)

      # Average proficiency across all students
      true ->
        calculate_average_proficiency(section, objective, state, proficiency)
    end
  end

  defp calculate_student_proficiency(section, objective, state, proficiency) do
    user = Engine.get_user(state, proficiency.student)

    if user == nil do
      {:error, "Student '#{proficiency.student}' not found"}
    else
      # Get the learning objective revisions
      learning_objectives = [objective]

      # Calculate proficiency using Metrics module
      proficiency_map =
        Metrics.proficiency_for_student_per_learning_objective(
          learning_objectives,
          user.id,
          section
        )

      # Get the proficiency for this objective
      case Map.get(proficiency_map, objective.resource_id) do
        nil ->
          {:ok, {0.0, "Not enough data"}}

        {value, bucket} ->
          {:ok, {value, bucket}}

        bucket when is_binary(bucket) ->
          # Sometimes it returns just the bucket string
          {:ok, {nil, bucket}}
      end
    end
  end

  defp calculate_average_proficiency(section, objective, _state, _proficiency) do
    # For average proficiency, we need to get all enrolled students
    # and calculate the average of their proficiency values

    # Get all enrolled students
    student_ids =
      Sections.list_enrollments(section.slug)
      # Student role
      |> Enum.filter(&(&1.user_role_id == 4))
      |> Enum.map(& &1.user_id)

    if Enum.empty?(student_ids) do
      {:ok, {0.0, "Not enough data"}}
    else
      # Get raw proficiency data for all students
      objective_type_id = Resources.ResourceType.id_for_objective()

      # Query for all students' proficiency data
      import Ecto.Query

      raw_data =
        from(summary in Oli.Analytics.Summary.ResourceSummary,
          where:
            summary.section_id == ^section.id and
              summary.project_id == -1 and
              summary.user_id in ^student_ids and
              summary.resource_id == ^objective.resource_id and
              summary.resource_type_id == ^objective_type_id,
          select: {
            summary.num_first_attempts_correct,
            summary.num_first_attempts,
            summary.num_correct,
            summary.num_attempts
          }
        )
        |> Repo.all()

      if Enum.empty?(raw_data) do
        {:ok, {0.0, "Not enough data"}}
      else
        # Calculate average proficiency
        {total_value, total_count} =
          raw_data
          |> Enum.reduce({0.0, 0}, fn {first_correct, first_count, _correct, _total},
                                      {sum, count} ->
            if first_count > 0 do
              value = (1.0 * first_correct + 0.2 * (first_count - first_correct)) / first_count
              {sum + value, count + 1}
            else
              {sum, count}
            end
          end)

        if total_count > 0 do
          avg_value = total_value / total_count
          # Use 3 as minimum for "enough data"
          bucket = Metrics.proficiency_range(avg_value, 3)
          {:ok, {avg_value, bucket}}
        else
          {:ok, {0.0, "Not enough data"}}
        end
      end
    end
  end

  defp format_value(nil), do: "nil"
  defp format_value(value) when is_float(value), do: Float.round(value, 2) |> to_string()
  defp format_value(value), do: to_string(value)
end
