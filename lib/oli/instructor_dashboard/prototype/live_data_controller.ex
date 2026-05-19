defmodule Oli.InstructorDashboard.Prototype.LiveDataController do
  @moduledoc """
  Prototype controller that orchestrates oracle loads, cache reads, and snapshot projection.
  """

  alias Oli.InstructorDashboard.Prototype.InProcessCache
  alias Oli.InstructorDashboard.Prototype.Scope
  alias Oli.InstructorDashboard.Prototype.Snapshot
  alias Oli.InstructorDashboard.Prototype.TileRegistry

  @type oracle_source :: :cache | :loaded | :skipped_optional | {:error, term()}

  def load(%Scope{} = scope, opts \\ []) do
    tiles = Keyword.get(opts, :tiles, TileRegistry.tiles())
    cache = Keyword.get(opts, :cache, InProcessCache.new())
    skip_optional = MapSet.new(Keyword.get(opts, :skip_optional, []))

    with {:ok, oracle_modules} <- TileRegistry.resolve_oracles(tiles) do
      {oracle_payloads, oracle_statuses, cache, oracle_sources} =
        load_oracles(scope, oracle_modules, cache, skip_optional)

      {:ok, snapshot} = Snapshot.project(scope, tiles, oracle_payloads, oracle_statuses)

      {:ok, snapshot, cache,
       %{
         oracle_sources: oracle_sources,
         cache_hits: count_sources(oracle_sources, :cache),
         loaded: count_sources(oracle_sources, :loaded),
         skipped_optional: count_sources(oracle_sources, :skipped_optional)
       }}
    end
  end

  defp load_oracles(scope, oracle_modules, cache, skip_optional) do
    Enum.reduce(oracle_modules, {%{}, %{}, cache, %{}}, fn {oracle_key, module, optional?},
                                                           {payloads, statuses, cache_acc,
                                                            sources} ->
      cond do
        optional? and MapSet.member?(skip_optional, oracle_key) ->
          {
            payloads,
            Map.put(statuses, oracle_key, {:error, :skipped_optional}),
            cache_acc,
            Map.put(sources, oracle_key, :skipped_optional)
          }

        true ->
          case InProcessCache.fetch(cache_acc, scope, oracle_key) do
            {:hit, payload} ->
              {
                Map.put(payloads, oracle_key, payload),
                Map.put(statuses, oracle_key, :ready),
                cache_acc,
                Map.put(sources, oracle_key, :cache)
              }

            :miss ->
              case module.load(scope, []) do
                {:ok, payload} ->
                  updated_cache = InProcessCache.put(cache_acc, scope, oracle_key, payload)

                  {
                    Map.put(payloads, oracle_key, payload),
                    Map.put(statuses, oracle_key, :ready),
                    updated_cache,
                    Map.put(sources, oracle_key, :loaded)
                  }

                {:error, reason} ->
                  {
                    payloads,
                    Map.put(statuses, oracle_key, {:error, reason}),
                    cache_acc,
                    Map.put(sources, oracle_key, {:error, reason})
                  }
              end
          end
      end
    end)
  end

  defp count_sources(sources, target) do
    Enum.count(sources, fn {_key, source} -> source == target end)
  end
end
