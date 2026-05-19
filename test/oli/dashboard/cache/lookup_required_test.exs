defmodule Oli.Dashboard.Cache.LookupRequiredTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Cache
  alias Oli.Dashboard.Cache.InProcessStore

  setup do
    clock_ref = start_supervised!({Agent, fn -> 0 end})
    clock = fn -> Agent.get(clock_ref, & &1) end

    {:ok, store} =
      start_supervised({InProcessStore, clock: clock, enrollment_count: 100})

    context = %{
      dashboard_context_type: :section,
      dashboard_context_id: 901,
      user_id: 777
    }

    %{store: store, clock_ref: clock_ref, context: context}
  end

  describe "lookup_required/4" do
    test "returns deterministic partial hits and misses with source tagging", %{
      store: store,
      context: context
    } do
      scope = %{container_type: :container, container_id: 7001}
      opts = cache_opts(store)

      assert :ok =
               Cache.write_oracle(
                 context,
                 scope,
                 :progress,
                 %{score: 91},
                 %{oracle_version: 1, data_version: 1},
                 opts
               )

      assert {:ok, result} =
               Cache.lookup_required(
                 context,
                 scope,
                 [:assessments, :progress, :objectives],
                 opts
               )

      assert result.hits == %{progress: %{score: 91}}
      assert result.misses == [:assessments, :objectives]
      assert result.source == :mixed
    end

    test "returns inprocess source for repeated warm lookup within ttl", %{
      store: store,
      context: context
    } do
      scope = %{container_type: :container, container_id: 8001}
      opts = cache_opts(store, ttl_ms: 500)

      assert :ok =
               Cache.write_oracle(
                 context,
                 scope,
                 :progress,
                 %{value: 12},
                 %{oracle_version: 1, data_version: 1},
                 opts
               )

      assert {:ok, first} = Cache.lookup_required(context, scope, [:progress], opts)
      assert {:ok, second} = Cache.lookup_required(context, scope, [:progress], opts)

      assert first.source == :inprocess
      assert first.misses == []
      assert first.hits == %{progress: %{value: 12}}

      assert second.source == :inprocess
      assert second.misses == []
      assert second.hits == %{progress: %{value: 12}}
    end

    test "degrades to deterministic misses when in-process store is unavailable", %{
      context: context
    } do
      scope = %{container_type: :container, container_id: 9001}

      assert {:ok, result} =
               Cache.lookup_required(
                 context,
                 scope,
                 [:progress, :objectives],
                 key_meta: %{oracle_version: 1, data_version: 1}
               )

      assert result.hits == %{}
      assert result.misses == [:progress, :objectives]
      assert result.source == :none
    end
  end

  describe "touch_container/3 recency wiring" do
    test "touch keeps recently-used container from being evicted", %{
      store: store,
      clock_ref: clock_ref,
      context: context
    } do
      opts = cache_opts(store, container_cap: 2)
      scope_one = %{container_type: :container, container_id: 1001}
      scope_two = %{container_type: :container, container_id: 1002}
      scope_three = %{container_type: :container, container_id: 1003}

      assert :ok =
               Cache.write_oracle(
                 context,
                 scope_one,
                 :progress,
                 %{value: 1},
                 %{oracle_version: 1, data_version: 1},
                 opts
               )

      advance_clock(clock_ref, 1)

      assert :ok =
               Cache.write_oracle(
                 context,
                 scope_two,
                 :progress,
                 %{value: 2},
                 %{oracle_version: 1, data_version: 1},
                 opts
               )

      advance_clock(clock_ref, 1)

      assert :ok = Cache.touch_container(context, scope_one, opts)

      advance_clock(clock_ref, 1)

      assert :ok =
               Cache.write_oracle(
                 context,
                 scope_three,
                 :progress,
                 %{value: 3},
                 %{oracle_version: 1, data_version: 1},
                 opts
               )

      assert {:ok, one_lookup} = Cache.lookup_required(context, scope_one, [:progress], opts)
      assert {:ok, two_lookup} = Cache.lookup_required(context, scope_two, [:progress], opts)
      assert {:ok, three_lookup} = Cache.lookup_required(context, scope_three, [:progress], opts)

      assert one_lookup.hits == %{progress: %{value: 1}}
      assert one_lookup.misses == []

      assert two_lookup.hits == %{}
      assert two_lookup.misses == [:progress]

      assert three_lookup.hits == %{progress: %{value: 3}}
      assert three_lookup.misses == []
    end
  end

  defp cache_opts(store, extra_opts \\ []) do
    Keyword.merge(
      [
        inprocess_store: store,
        key_meta: %{oracle_version: 1, data_version: 1},
        ttl_ms: 1_000
      ],
      extra_opts
    )
  end

  defp advance_clock(clock_ref, milliseconds) do
    Agent.update(clock_ref, &(&1 + milliseconds))
  end
end
