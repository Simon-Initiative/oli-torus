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
        parent_title =
          case Map.get(row, :row_type) do
            :subobjective -> Map.get(row, :parent_title, "")
            _ -> Map.get(row, :title, "")
          end

        child_title =
          case Map.get(row, :row_type) do
            :subobjective -> Map.get(row, :title, "")
            _ -> ""
          end

        label =
          case Map.get(row, :row_type) do
            :subobjective -> Map.get(row, :numbering, "")
            _ -> format_objective_label(Map.get(row, :numbering))
          end

        [
          label,
          parent_title,
          child_title,
          Map.get(row, :proficiency_label, "")
        ]
      end)

    case rows do
      [] ->
        {:skip, :dataset_no_data}

      _ ->
        Helpers.encode_csv(["label", "objective", "sub_objective", "proficiency"], rows)
    end
  end

  defp format_objective_label(numbering) when is_binary(numbering) and numbering != "",
    do: "LO #{numbering}"

  defp format_objective_label(_), do: ""
end
