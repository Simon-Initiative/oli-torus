defmodule Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.AssessmentSummary do
  @moduledoc false

  alias Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.Helpers

  @spec serialize(map(), map()) :: {:ok, binary()} | {:skip, atom()} | {:error, term()}
  def serialize(snapshot_bundle, _dataset_spec) do
    rows =
      snapshot_bundle
      |> Helpers.projection(:assessments, [:assessments, :rows])
      |> List.wrap()
      |> Enum.map(fn assessment ->
        completed = get_in(assessment, [:completion, :completed_count]) || 0
        total = get_in(assessment, [:completion, :total_students]) || 0

        [
          Map.get(assessment, :title, ""),
          Helpers.format_date(Map.get(assessment, :available_at)),
          Helpers.format_date(Map.get(assessment, :due_at)),
          completed,
          max(total - completed, 0),
          Helpers.format_metric_number(get_in(assessment, [:metrics, :minimum])),
          Helpers.format_metric_number(get_in(assessment, [:metrics, :median])),
          Helpers.format_metric_number(get_in(assessment, [:metrics, :mean])),
          Helpers.format_metric_number(get_in(assessment, [:metrics, :maximum])),
          Helpers.format_metric_number(get_in(assessment, [:metrics, :standard_deviation]))
        ]
      end)

    case rows do
      [] ->
        {:skip, :dataset_no_data}

      _ ->
        Helpers.encode_csv(
          [
            "assessment_name",
            "available_from",
            "due_date",
            "students_completed",
            "students_not_completed",
            "score_min",
            "score_median",
            "score_mean",
            "score_max",
            "score_std_dev"
          ],
          rows
        )
    end
  end
end
