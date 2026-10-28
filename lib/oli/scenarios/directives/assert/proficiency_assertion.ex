defmodule Oli.Scenarios.Directives.Assert.ProficiencyAssertion do
  @moduledoc """
  Handles proficiency assertions for learning objectives.

  Student assertions consume canonical estimates; class assertions consume canonical
  aggregates. This keeps scenario coverage on the same Section-selected provider path
  as production consumers and preserves the distinction between missing evidence and 0.0.
  """

  alias Oli.Scenarios.DirectiveTypes.{AssertDirective, VerificationResult}
  alias Oli.Scenarios.Engine
  alias Oli.Delivery.Proficiency
  alias Oli.Delivery.Sections

  @doc """
  Asserts proficiency for a learning objective.

  The proficiency assertion checks:
  - The proficiency bucket (High/Medium/Low/Not enough data)
  - Optionally, the raw proficiency value (0.0-1.0)

  It can target a specific student or aggregate all enrolled learners.
  """
  def assert(%AssertDirective{proficiency: proficiency}, state) when is_map(proficiency) do
    with {:ok, section} <- get_section(state, proficiency.section),
         {:ok, objective} <- find_objective_by_title(state, section, proficiency.objective),
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

      bucket_matches = actual_bucket == expected_bucket

      value_matches =
        case {expected_value, actual_value} do
          {nil, _actual} ->
            true

          {expected, actual} when is_number(expected) and is_number(actual) ->
            Float.round(actual, 2) == Float.round(expected, 2)

          {_expected, _actual} ->
            false
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

  defp find_objective_by_title(state, section, objective_title) do
    objective =
      state.projects
      |> Enum.find_value(fn {_name, built_project} ->
        case built_project do
          %{project: %{id: project_id}, objectives_by_title: objectives}
          when project_id == section.base_project_id and is_map(objectives) ->
            Map.get(objectives, objective_title)

          _other ->
            nil
        end
      end)

    case objective do
      nil -> {:error, "Learning objective '#{objective_title}' not found"}
      obj -> {:ok, obj}
    end
  end

  defp calculate_proficiency(section, objective, state, proficiency) do
    case proficiency.student do
      nil -> calculate_average_proficiency(section, objective, state, proficiency)
      _student -> calculate_student_proficiency(section, objective, state, proficiency)
    end
  end

  defp calculate_student_proficiency(section, objective, state, proficiency) do
    user = Engine.get_user(state, proficiency.student)

    if user == nil do
      {:error, "Student '#{proficiency.student}' not found"}
    else
      case Proficiency.estimates_for_objectives(
             section,
             [user.id],
             [objective.resource_id]
           ) do
        {:ok, estimates} ->
          estimate = get_in(estimates, [objective.resource_id, user.id])
          {:ok, estimate_result(estimate)}

        {:error, reason} ->
          {:error, "proficiency provider unavailable: #{inspect(reason)}"}
      end
    end
  end

  defp calculate_average_proficiency(section, objective, _state, _proficiency) do
    # For average proficiency, we need to get all enrolled students
    # and calculate the average of their proficiency values

    # Get all enrolled students
    student_ids =
      Sections.list_enrollments(section.slug)
      |> Enum.filter(fn enrollment ->
        Enum.any?(enrollment.context_roles, &String.ends_with?(&1.uri, "#Learner"))
      end)
      |> Enum.map(& &1.user_id)

    if Enum.empty?(student_ids) do
      {:ok, {nil, "Not enough data"}}
    else
      case Proficiency.objective_aggregates(section, [objective.resource_id],
             user_ids: student_ids
           ) do
        {:ok, aggregates} ->
          aggregate = Map.get(aggregates, objective.resource_id)
          {:ok, aggregate_result(section, aggregate)}

        {:error, reason} ->
          {:error, "proficiency provider unavailable: #{inspect(reason)}"}
      end
    end
  end

  defp estimate_result(nil), do: {nil, "Not enough data"}
  defp estimate_result(estimate), do: {estimate.score, label_string(estimate.label)}

  defp aggregate_result(_section, nil), do: {nil, "Not enough data"}
  defp aggregate_result(_section, %{numeric_score: nil}), do: {nil, "Not enough data"}

  defp aggregate_result(section, %{numeric_score: score}) do
    {score, Proficiency.label_for_score(section, score)}
  end

  defp label_string(:low), do: "Low"
  defp label_string(:medium), do: "Medium"
  defp label_string(:high), do: "High"
  defp label_string(_label), do: "Not enough data"

  defp format_value(nil), do: "nil"
  defp format_value(value) when is_float(value), do: Float.round(value, 2) |> to_string()
  defp format_value(value), do: to_string(value)
end
