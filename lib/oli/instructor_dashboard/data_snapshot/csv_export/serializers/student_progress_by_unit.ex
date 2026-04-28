defmodule Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.StudentProgressByUnit do
  @moduledoc false

  alias Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.Helpers
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Progress.Projector

  @spec serialize(map(), map()) :: {:ok, binary()} | {:skip, atom()} | {:error, term()}
  def serialize(snapshot_bundle, dataset_spec) do
    progress_tile =
      snapshot_bundle
      |> Helpers.projection(:progress, [:progress_tile])
      |> Kernel.||(%{})
      |> Projector.reproject(%{
        completion_threshold: Helpers.progress_threshold(dataset_spec),
        page: 1
      })

    rows =
      progress_tile
      |> Map.get(:series_all, [])
      |> Enum.map(fn series ->
        [
          Map.get(series, :label, ""),
          Map.get(series, :count, 0),
          Helpers.format_one_decimal(Map.get(series, :percent))
        ]
      end)

    case rows do
      [] -> {:skip, :dataset_no_data}
      _ -> Helpers.encode_csv(["content_item", "students_completed", "completion_rate"], rows)
    end
  end
end
