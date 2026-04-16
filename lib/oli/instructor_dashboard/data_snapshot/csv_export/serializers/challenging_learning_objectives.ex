defmodule Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.ChallengingLearningObjectives do
  @moduledoc false

  alias Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.Helpers

  @spec serialize(map(), map()) :: {:ok, binary()} | {:skip, atom()} | {:error, term()}
  def serialize(snapshot_bundle, _dataset_spec) do
    rows =
      snapshot_bundle
      |> Helpers.projection(:challenging_objectives, [:rows])
      |> List.wrap()
      |> Helpers.flatten_tree_rows()
      |> Enum.filter(&(Map.get(&1, :proficiency_label) == "Low"))
      |> Enum.map(fn row ->
        [
          Map.get(row, :objective_id),
          Map.get(row, :title, ""),
          Map.get(row, :proficiency_label, "")
        ]
      end)

    case rows do
      [] ->
        {:skip, :dataset_no_data}

      _ ->
        Helpers.encode_csv(["objective_id", "objective_text", "proficiency"], rows)
    end
  end
end
