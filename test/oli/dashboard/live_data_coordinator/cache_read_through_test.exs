defmodule Oli.Dashboard.LiveDataCoordinator.CacheReadThroughTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Cache
  alias Oli.Dashboard.Cache.InProcessStore
  alias Oli.Dashboard.Cache.Key
  alias Oli.Dashboard.Cache.MissCoalescer

  defmodule ConsumerHarness do
    alias Oli.Dashboard.Cache
    alias Oli.Dashboard.Cache.Key

    def load_required(context, scope, required_oracles, opts, loader_fun) do
      {:ok, lookup} = Cache.lookup_required(context, scope, required_oracles, opts)

      built_hits =
        Enum.reduce(lookup.misses, %{}, fn oracle_key, acc ->
          meta = key_meta_for_oracle(opts, oracle_key)
          {:ok, cache_key} = Key.inprocess(context, scope, oracle_key, meta)

          case Cache.coalesce_or_build(cache_key, fn -> {:ok, loader_fun.(oracle_key)} end, opts) do
            {:ok, payload} ->
              _ = Cache.write_oracle(context, scope, oracle_key, payload, meta, opts)
              Map.put(acc, oracle_key, payload)

            {:error, _reason} ->
              acc
          end
        end)

      hits = Map.merge(lookup.hits, built_hits)
      misses = required_oracles |> Enum.reject(&Map.has_key?(hits, &1))

      %{hits: hits, misses: misses}
    end

    defp key_meta_for_oracle(opts, oracle_key) do
      default_meta = Keyword.get(opts, :key_meta, %{oracle_version: 1, data_version: 1})
      per_oracle = Keyword.get(opts, :key_meta_by_oracle, %{})

      case per_oracle do
        %{} ->
          Map.get(per_oracle, oracle_key, default_meta)

        _ ->
          default_meta
      end
    end
  end

  setup do
    inprocess_store = start_supervised!({InProcessStore, enrollment_count: 100})
    miss_coalescer = start_supervised!({MissCoalescer, []})

    context = %{
      dashboard_context_type: :section,
      dashboard_context_id: 501,
      user_id: 1001
    }

    scope = %{container_type: :container, container_id: 7001}

    opts = [
      inprocess_store: inprocess_store,
      miss_coalescer: miss_coalescer,
      key_meta: %{oracle_version: 1, data_version: 1}
    ]

    %{context: context, scope: scope, opts: opts}
  end

  test "consumer read-through produces deterministic partial then warm full hits", %{
    context: context,
    scope: scope,
    opts: opts
  } do
    loader =
      fn
        :progress -> %{value: 80}
        :objectives -> %{value: 64}
      end

    first =
      ConsumerHarness.load_required(context, scope, [:progress, :objectives], opts, loader)

    assert first.misses == []
    assert first.hits == %{progress: %{value: 80}, objectives: %{value: 64}}

    second =
      ConsumerHarness.load_required(context, scope, [:progress, :objectives], opts, fn _ ->
        flunk("warm lookup should not invoke loader")
      end)

    assert second.misses == []
    assert second.hits == %{progress: %{value: 80}, objectives: %{value: 64}}
  end

  test "consumer read-through continues when inprocess store and coalescer are unavailable", %{
    context: context,
    scope: scope
  } do
    opts = [key_meta: %{oracle_version: 1, data_version: 1}]

    result =
      ConsumerHarness.load_required(
        context,
        scope,
        [:progress, :objectives],
        opts,
        fn oracle_key -> %{oracle: oracle_key, uncached: true} end
      )

    assert result.misses == []

    assert result.hits == %{
             progress: %{oracle: :progress, uncached: true},
             objectives: %{oracle: :objectives, uncached: true}
           }
  end
end
