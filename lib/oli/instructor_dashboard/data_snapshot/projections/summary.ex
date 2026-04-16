defmodule Oli.InstructorDashboard.DataSnapshot.Projections.Summary do
  @moduledoc """
  Instructor summary projection.
  """

  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Helpers

  @objective_proficiency_weights %{
    "Low" => 20.0,
    "Medium" => 60.0,
    "High" => 100.0
  }

  @required_oracles []

  @optional_oracles [
    :oracle_instructor_scope_resources,
    :oracle_instructor_progress_bins,
    :oracle_instructor_progress_proficiency,
    :oracle_instructor_grades,
    :oracle_instructor_objectives_proficiency
  ]

  @spec required_oracles() :: [atom()]
  def required_oracles, do: @required_oracles

  @spec optional_oracles() :: [atom()]
  def optional_oracles, do: @optional_oracles

  @spec derive(Contract.t(), keyword()) ::
          {:ok, map()} | {:partial, map(), term()} | {:error, term()}
  def derive(%Contract{} = snapshot, _opts) do
    with {:ok, required} <- Helpers.require_oracles(snapshot, @required_oracles) do
      optional = Helpers.optional_oracles(snapshot, @optional_oracles)
      missing_optional = Helpers.missing_optional_oracles(snapshot, @optional_oracles)

      projection =
        Helpers.projection_base(snapshot, :summary, %{
          scope: scope_data(snapshot, optional),
          metrics: metrics(optional),
          total_students: total_students(optional),
          required_oracles: required,
          optional_oracles: optional,
          missing_optional_oracles: missing_optional
        })

      case missing_optional do
        [] -> {:ok, projection}
        missing -> {:partial, projection, {:dependency_unavailable, missing}}
      end
    end
  end

  defp scope_data(snapshot, optional) do
    scope_resources = Map.get(optional, :oracle_instructor_scope_resources, %{})

    %{
      selector: scope_selector(snapshot.scope),
      label: Map.get(scope_resources, :scope_label, scope_label(snapshot.scope)),
      course_title: Map.get(scope_resources, :course_title)
    }
  end

  defp metrics(optional) do
    %{
      average_class_proficiency: average_class_proficiency(optional),
      average_assessment_score: average_assessment_score(optional),
      average_student_progress: average_student_progress(optional)
    }
  end

  defp average_student_progress(optional) do
    optional
    |> Map.get(:oracle_instructor_progress_proficiency, [])
    |> List.wrap()
    |> Enum.map(&Map.get(&1, :progress_pct))
    |> average()
  end

  defp average_assessment_score(optional) do
    optional
    |> Map.get(:oracle_instructor_grades, %{})
    |> Map.get(:grades, [])
    |> List.wrap()
    |> Enum.map(&Map.get(&1, :mean))
    |> average()
  end

  defp average_class_proficiency(optional) do
    optional
    |> Map.get(:oracle_instructor_objectives_proficiency, %{})
    |> Map.get(:objective_rows, [])
    |> List.wrap()
    |> Enum.map(fn row ->
      row
      |> Map.get(:proficiency_distribution, %{})
      |> objective_average_proficiency()
    end)
    |> average()
  end

  defp total_students(optional) do
    candidates = [
      get_in(optional, [:oracle_instructor_progress_bins, :total_students]),
      optional
      |> Map.get(:oracle_instructor_progress_proficiency, [])
      |> List.wrap()
      |> length(),
      optional
      |> Map.get(:oracle_instructor_grades, %{})
      |> Map.get(:grades, [])
      |> List.wrap()
      |> Enum.map(&Map.get(&1, :total_students))
      |> Enum.reject(&is_nil/1)
      |> Enum.max(fn -> nil end)
    ]

    candidates
    |> Enum.reject(&is_nil/1)
    |> Enum.max(fn -> 0 end)
  end

  defp scope_selector(%{container_type: :container, container_id: container_id}),
    do: "container:#{container_id}"

  defp scope_selector(_scope), do: "course"

  defp scope_label(%{container_type: :course}), do: "Entire Course"
  defp scope_label(%{container_type: :container}), do: "Selected Scope"
  defp scope_label(_scope), do: "Selected Scope"

  defp average(values) do
    values =
      values
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&to_float/1)

    case values do
      [] -> nil
      _ -> Float.round(Enum.sum(values) / length(values), 1)
    end
  end

  defp objective_average_proficiency(nil), do: nil

  defp objective_average_proficiency(distribution) when is_map(distribution) do
    weighted_total =
      Enum.reduce(@objective_proficiency_weights, 0.0, fn {label, weight}, acc ->
        acc + weight * normalize_count(Map.get(distribution, label))
      end)

    student_count =
      @objective_proficiency_weights
      |> Map.keys()
      |> Enum.reduce(0, fn label, acc -> acc + normalize_count(Map.get(distribution, label)) end)

    case student_count do
      0 -> nil
      _ -> Float.round(weighted_total / student_count, 1)
    end
  end

  defp normalize_count(value) when is_integer(value) and value >= 0, do: value
  defp normalize_count(value) when is_float(value) and value >= 0.0, do: trunc(value)
  defp normalize_count(_), do: 0

  defp to_float(value) when is_integer(value), do: value * 1.0
  defp to_float(value) when is_float(value), do: value
end
