defmodule Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.StudentSupportSummary do
  @moduledoc false

  alias Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.Helpers

  @spec serialize(map(), map()) :: {:ok, binary()} | {:skip, atom()} | {:error, term()}
  def serialize(snapshot_bundle, _dataset_spec) do
    rows =
      snapshot_bundle
      |> Helpers.projection(:student_support, [:support, :buckets])
      |> List.wrap()
      |> Enum.map(fn bucket ->
        [
          Helpers.normalize_category(Map.get(bucket, :id)),
          Map.get(bucket, :count, 0),
          Helpers.format_one_decimal((Map.get(bucket, :pct, 0.0) || 0.0) * 100.0)
        ]
      end)

    case rows do
      [] -> {:skip, :dataset_no_data}
      _ -> Helpers.encode_csv(["category", "student_count", "percentage"], rows)
    end
  end
end
