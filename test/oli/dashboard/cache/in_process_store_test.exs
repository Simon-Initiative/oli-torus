defmodule Oli.Dashboard.Cache.InProcessStoreTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Cache.InProcessStore
  alias Oli.Dashboard.Cache.Key

  setup do
    clock_ref = start_supervised!({Agent, fn -> 0 end})
    clock = fn -> Agent.get(clock_ref, & &1) end

    {:ok, store} =
      start_supervised({InProcessStore, clock: clock, enrollment_count: 100})

    %{store: store, clock_ref: clock_ref}
  end

  describe "lookup_required/3" do
    test "returns warm hit while entry is within ttl", %{store: store} do
      key = cache_key(:progress, 101)

      assert {:ok, %{evicted_containers: 0}} =
               InProcessStore.write_oracle(store, key, %{value: 88},
                 ttl_ms: 1_000,
                 container_cap: 5
               )

      assert {:ok, result} = InProcessStore.lookup_required(store, [key], ttl_ms: 1_000)
      assert result.hits == %{key => %{value: 88}}
      assert result.misses == []
      assert result.expired == []
    end

    test "stores and returns list payloads while entry is within ttl", %{store: store} do
      key = cache_key(:progress_proficiency, 303)
      payload = [%{student_id: 1, progress_pct: 88.0, proficiency_pct: 71.0}]

      assert {:ok, %{evicted_containers: 0}} =
               InProcessStore.write_oracle(store, key, payload,
                 ttl_ms: 1_000,
                 container_cap: 5
               )

      assert {:ok, result} = InProcessStore.lookup_required(store, [key], ttl_ms: 1_000)
      assert result.hits == %{key => payload}
      assert result.misses == []
      assert result.expired == []
    end

    test "expires ttl entries deterministically and treats them as misses", %{
      store: store,
      clock_ref: clock_ref
    } do
      key = cache_key(:objectives, 202)

      assert {:ok, %{evicted_containers: 0}} =
               InProcessStore.write_oracle(store, key, %{value: 42}, ttl_ms: 50, container_cap: 5)

      advance_clock(clock_ref, 51)

      assert {:ok, first_lookup} = InProcessStore.lookup_required(store, [key], ttl_ms: 50)
      assert first_lookup.hits == %{}
      assert first_lookup.misses == [key]
      assert first_lookup.expired == [key]

      assert {:ok, second_lookup} = InProcessStore.lookup_required(store, [key], ttl_ms: 50)
      assert second_lookup.hits == %{}
      assert second_lookup.misses == [key]
      assert second_lookup.expired == []
    end
  end

  describe "container-level eviction" do
    test "evicts least-recently-used container entries as a group", %{
      store: store,
      clock_ref: clock_ref
    } do
      c1_oracle_a = cache_key(:progress, 1)
      c1_oracle_b = cache_key(:assessments, 1)
      c2_oracle_a = cache_key(:objectives, 2)
      c3_oracle_a = cache_key(:support, 3)

      assert {:ok, %{evicted_containers: 0}} =
               InProcessStore.write_oracle(store, c1_oracle_a, %{v: 1}, container_cap: 2)

      advance_clock(clock_ref, 1)

      assert {:ok, %{evicted_containers: 0}} =
               InProcessStore.write_oracle(store, c1_oracle_b, %{v: 2}, container_cap: 2)

      advance_clock(clock_ref, 1)

      assert {:ok, %{evicted_containers: 0}} =
               InProcessStore.write_oracle(store, c2_oracle_a, %{v: 3}, container_cap: 2)

      advance_clock(clock_ref, 1)

      assert {:ok, %{evicted_containers: 0}} =
               InProcessStore.touch_container(store, 500, :container, 2, container_cap: 2)

      advance_clock(clock_ref, 1)

      assert {:ok, %{evicted_containers: 1}} =
               InProcessStore.write_oracle(store, c3_oracle_a, %{v: 4}, container_cap: 2)

      assert {:ok, lookup} =
               InProcessStore.lookup_required(
                 store,
                 [c1_oracle_a, c1_oracle_b, c2_oracle_a, c3_oracle_a],
                 ttl_ms: 1_000
               )

      assert lookup.hits == %{c2_oracle_a => %{v: 3}, c3_oracle_a => %{v: 4}}
      assert lookup.misses == [c1_oracle_a, c1_oracle_b]

      assert {:ok, snapshot} = InProcessStore.snapshot(store)
      assert map_size(snapshot.container_access) == 2
    end
  end

  describe "error reply handling" do
    test "returns error reply for invalid cache key write without crashing", %{store: store} do
      assert {:error, {:invalid_cache_key, {:unsupported_key_shape, {:bad, :key}}}} =
               InProcessStore.write_oracle(store, {:bad, :key}, %{value: 1}, container_cap: 5)

      assert {:ok, _snapshot} = InProcessStore.snapshot(store)
    end

    test "returns error reply for invalid touch container input without crashing", %{store: store} do
      assert {:error, {:invalid_context_id, 0}} =
               InProcessStore.touch_container(store, 0, :container, 1, container_cap: 5)

      assert {:error, {:invalid_container, :container, -1}} =
               InProcessStore.touch_container(store, 500, :container, -1, container_cap: 5)

      assert {:ok, _snapshot} = InProcessStore.snapshot(store)
    end
  end

  defp cache_key(oracle_key, container_id) do
    {:ok, key} =
      Key.inprocess(
        %{dashboard_context_id: 500},
        %{container_type: :container, container_id: container_id},
        oracle_key,
        %{oracle_version: 1, data_version: 1}
      )

    key
  end

  defp advance_clock(clock_ref, milliseconds) do
    Agent.update(clock_ref, &(&1 + milliseconds))
  end
end
