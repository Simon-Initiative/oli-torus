defmodule Oli.InstructorDashboard.Prototype.TileRegistry do
  @moduledoc """
  Prototype registry for tile definitions and shared oracle resolution.
  """

  alias Oli.InstructorDashboard.Prototype.Tiles.Progress
  alias Oli.InstructorDashboard.Prototype.Tiles.StudentSupport

  @tiles [Progress, StudentSupport]

  def tiles, do: @tiles

  def resolve_oracles(tiles) do
    tiles
    |> Enum.reduce_while(%{}, fn tile, acc ->
      with {:ok, acc} <- merge_oracles(acc, tile.required_oracles(), false),
           {:ok, acc} <- merge_oracles(acc, tile.optional_oracles(), true) do
        {:cont, acc}
      else
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:error, _} = error -> error
      acc -> {:ok, to_oracle_list(acc)}
    end
  end

  def project_all(snapshot, tiles) do
    Enum.reduce(tiles, {%{}, %{}}, fn tile, {projections, statuses} ->
      case tile.project(snapshot) do
        {:ok, projection} ->
          {Map.put(projections, tile.key(), projection), Map.put(statuses, tile.key(), :ready)}

        {:error, reason} ->
          {projections, Map.put(statuses, tile.key(), {:error, reason})}
      end
    end)
  end

  defp merge_oracles(acc, oracle_map, optional?) do
    Enum.reduce_while(oracle_map, acc, fn {_slot, module}, inner_acc ->
      oracle_key = module.key()

      case Map.get(inner_acc, oracle_key) do
        nil ->
          {:cont, Map.put(inner_acc, oracle_key, {module, optional?})}

        {^module, existing_optional?} ->
          optional_flag = existing_optional? and optional?
          {:cont, Map.put(inner_acc, oracle_key, {module, optional_flag})}

        {existing_module, _} ->
          {:halt, {:error, {:oracle_key_conflict, oracle_key, existing_module, module}}}
      end
    end)
    |> case do
      {:error, _} = error -> error
      acc -> {:ok, acc}
    end
  end

  defp to_oracle_list(oracle_map) do
    Enum.map(oracle_map, fn {oracle_key, {module, optional?}} ->
      {oracle_key, module, optional?}
    end)
  end
end
