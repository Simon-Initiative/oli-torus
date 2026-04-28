defmodule Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.AssessmentScoresDistribution do
  @moduledoc false

  alias Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.Helpers

  @spec serialize(map(), map()) :: {:ok, binary()} | {:skip, atom()} | {:error, term()}
  def serialize(snapshot_bundle, _dataset_spec) do
    rows =
      snapshot_bundle
      |> Helpers.projection(:assessments, [:assessments, :rows])
      |> Kernel.||([])
      |> List.wrap()
      |> Enum.flat_map(fn assessment ->
        title = Map.get(assessment, :title, "")

        assessment
        |> Map.get(:histogram_bins, [])
        |> Enum.filter(fn bin -> (Map.get(bin, :count) || 0) > 0 end)
        |> Enum.map(fn bin ->
          [title, Map.get(bin, :range, ""), Map.get(bin, :count, 0)]
        end)
      end)

    case rows do
      [] -> {:skip, :dataset_no_data}
      _ -> Helpers.encode_csv(["assessment_name", "score_range", "student_count"], rows)
    end
  end
end
