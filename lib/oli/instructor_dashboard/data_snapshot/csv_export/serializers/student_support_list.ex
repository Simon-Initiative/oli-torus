defmodule Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.StudentSupportList do
  @moduledoc false

  alias Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.Helpers

  @spec serialize(map(), map()) :: {:ok, binary()} | {:skip, atom()} | {:error, term()}
  def serialize(snapshot_bundle, _dataset_spec) do
    rows =
      snapshot_bundle
      |> Helpers.projection(:student_support, [:support, :buckets])
      |> Kernel.||([])
      |> List.wrap()
      |> Enum.flat_map(fn bucket ->
        category = Helpers.normalize_category(Map.get(bucket, :id))

        bucket
        |> Map.get(:students, [])
        |> Enum.map(fn student ->
          [
            Map.get(student, :student_id),
            Map.get(student, :display_name, ""),
            Helpers.format_metric_number(Map.get(student, :progress_pct)),
            Helpers.format_metric_number(Map.get(student, :proficiency_pct)),
            category,
            Helpers.format_bool(Map.get(student, :activity_status) == :inactive)
          ]
        end)
      end)

    case rows do
      [] ->
        {:skip, :dataset_no_data}

      _ ->
        Helpers.encode_csv(
          [
            "student_id",
            "student_name",
            "progress_pct",
            "proficiency_pct",
            "support_category",
            "inactive"
          ],
          rows
        )
    end
  end
end
