defmodule Oli.InstructorDashboard.DataSnapshot.CsvExport.Serializers.MapRows do
  @moduledoc false

  @spec serialize(map(), map()) :: {:ok, binary()} | {:error, term()}
  def serialize(snapshot_bundle, dataset_spec) do
    dataset_id = Map.fetch!(dataset_spec, :dataset_id)
    projection_map = Map.get(snapshot_bundle, :projections, %{})

    case Map.fetch(projection_map, dataset_id) do
      {:ok, projection} ->
        {:ok, encode_projection_csv(projection)}

      :error ->
        {:error, {:missing_projection, dataset_id}}
    end
  end

  defp encode_projection_csv(%{} = projection) do
    rows =
      projection
      |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
      |> Enum.map(fn {key, value} -> [to_string(key), render_value(value)] end)

    rows
    |> CSV.encode(headers: ["field", "value"])
    |> Enum.join()
  end

  defp encode_projection_csv(other) do
    [[to_string(:value), render_value(other)]]
    |> CSV.encode(headers: ["field", "value"])
    |> Enum.join()
  end

  defp render_value(value) when is_binary(value), do: value
  defp render_value(value) when is_number(value), do: to_string(value)
  defp render_value(value) when is_boolean(value), do: to_string(value)
  defp render_value(nil), do: ""
  defp render_value(value), do: inspect(value)
end
