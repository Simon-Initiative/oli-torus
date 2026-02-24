defmodule Oli.Dashboard.Cache.FacadeIntegrationTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Cache
  alias Oli.Dashboard.Cache.Key
  alias Oli.Dashboard.Cache.MissCoalescer

  describe "coalesce_or_build/3 facade integration" do
    test "coalesces concurrent identical misses to one producer build" do
      coalescer = start_supervised!({MissCoalescer, []})
      counter = start_supervised!({Agent, fn -> 0 end})

      cache_key = inprocess_key(:progress)

      # Stubbed participant: shared build function increments a single counter.
      build_fun = fn ->
        Agent.update(counter, &(&1 + 1))
        Process.sleep(25)
        {:ok, %{value: 99}}
      end

      tasks =
        Enum.map(1..5, fn _ ->
          Task.async(fn ->
            Cache.coalesce_or_build(
              cache_key,
              build_fun,
              miss_coalescer: coalescer,
              coalescer_timeout_ms: 500
            )
          end)
        end)

      results = Enum.map(tasks, &Task.await(&1, 1_000))

      assert Enum.all?(results, fn result -> result == {:ok, %{value: 99}} end)
      assert Agent.get(counter, & &1) == 1
    end

    test "falls back to non-coalesced build when coalescer is unavailable" do
      counter = start_supervised!({Agent, fn -> 0 end})
      cache_key = inprocess_key(:progress)

      build_fun = fn ->
        Agent.update(counter, &(&1 + 1))
        {:ok, %{value: 11}}
      end

      assert {:ok, %{value: 11}} = Cache.coalesce_or_build(cache_key, build_fun, [])
      assert Agent.get(counter, & &1) == 1
    end

    test "waiters receive shared error when producer build fails" do
      coalescer = start_supervised!({MissCoalescer, []})
      counter = start_supervised!({Agent, fn -> 0 end})
      cache_key = inprocess_key(:objectives)

      build_fun = fn ->
        Agent.update(counter, &(&1 + 1))
        {:error, :oracle_failure}
      end

      tasks =
        Enum.map(1..3, fn _ ->
          Task.async(fn ->
            Cache.coalesce_or_build(
              cache_key,
              build_fun,
              miss_coalescer: coalescer,
              coalescer_timeout_ms: 500
            )
          end)
        end)

      results = Enum.map(tasks, &Task.await(&1, 1_000))

      assert Enum.all?(results, fn result -> result == {:error, :oracle_failure} end)
      assert Agent.get(counter, & &1) == 1
    end
  end

  defp inprocess_key(oracle_key) do
    {:ok, key} =
      Key.inprocess(
        %{dashboard_context_id: 123},
        %{container_type: :container, container_id: 456},
        oracle_key,
        %{oracle_version: 1, data_version: 1}
      )

    key
  end
end
