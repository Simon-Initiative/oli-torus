defmodule Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.CourseSummaryMetrics do
  @moduledoc false

  alias Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.Helpers

  @spec serialize(map(), map()) :: {:ok, binary()} | {:skip, atom()} | {:error, term()}
  def serialize(snapshot_bundle, _dataset_spec) do
    rows =
      [
        metric_row(
          "average_class_proficiency",
          average_class_proficiency(snapshot_bundle)
        ),
        metric_row(
          "average_assessment_score",
          average_assessment_score(snapshot_bundle)
        ),
        metric_row(
          "average_student_progress",
          average_student_progress(snapshot_bundle)
        )
      ]
      |> Enum.reject(&is_nil/1)

    case rows do
      [] -> {:skip, :dataset_no_data}
      _ -> Helpers.encode_csv(["metric", "value", "unit"], rows)
    end
  end

  defp metric_row(_metric, nil), do: nil

  defp metric_row(metric, value) do
    [metric, Helpers.format_metric_number(value), "percent"]
  end

  defp average_student_progress(snapshot_bundle) do
    snapshot_bundle
    |> get_in([:snapshot, :oracles, :oracle_instructor_progress_proficiency])
    |> List.wrap()
    |> Enum.map(&Map.get(&1, :progress_pct))
    |> Helpers.average()
  end

  defp average_assessment_score(snapshot_bundle) do
    snapshot_bundle
    |> get_in([:snapshot, :oracles, :oracle_instructor_grades, :grades])
    |> List.wrap()
    |> Enum.map(&Map.get(&1, :mean))
    |> Helpers.average()
  end

  defp average_class_proficiency(snapshot_bundle) do
    snapshot_bundle
    |> get_in([:snapshot, :oracles, :oracle_instructor_objectives_proficiency, :objective_rows])
    |> List.wrap()
    |> Enum.map(fn row ->
      row
      |> Map.get(:proficiency_distribution, %{})
      |> Helpers.objective_average_proficiency()
    end)
    |> Helpers.average()
  end
end
