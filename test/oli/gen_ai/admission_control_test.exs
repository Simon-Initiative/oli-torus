defmodule Oli.GenAI.AdmissionControlTest do
  use ExUnit.Case, async: false

  alias Oli.GenAI.AdmissionControl

  setup do
    ensure_started(AdmissionControl)
    clear_tables()
    :ok
  end

  test "increments and decrements request counters concurrently" do
    service_config_id = 101

    1..100
    |> Task.async_stream(
      fn _ ->
        AdmissionControl.increment_requests(service_config_id)
        AdmissionControl.decrement_requests(service_config_id)
      end,
      timeout: 5_000
    )
    |> Enum.to_list()

    assert AdmissionControl.counts(service_config_id).requests == 0
  end

  test "stream counters are tracked separately" do
    service_config_id = 102

    AdmissionControl.increment_requests(service_config_id)
    AdmissionControl.increment_streams(service_config_id)

    assert AdmissionControl.counts(service_config_id) == %{requests: 1, streams: 1}

    AdmissionControl.decrement_streams(service_config_id)
    AdmissionControl.decrement_requests(service_config_id)

    assert AdmissionControl.counts(service_config_id) == %{requests: 0, streams: 0}
  end

  test "atomically admits model slots up to hard limit" do
    model_id = 55
    hard_limit = 10

    results =
      1..50
      |> Task.async_stream(fn _ -> AdmissionControl.try_admit_model(model_id, hard_limit) end,
        timeout: 5_000
      )
      |> Enum.map(fn {:ok, result} -> result end)

    admitted = Enum.count(results, &(&1 == :ok))
    rejected = Enum.count(results, &(&1 == {:error, :over_capacity}))

    assert admitted == hard_limit
    assert rejected == 40
    assert AdmissionControl.model_count(model_id) == hard_limit

    Enum.each(1..hard_limit, fn _ -> AdmissionControl.release_model(model_id) end)
    assert AdmissionControl.model_count(model_id) == 0
  end

  test "atomically admits pool slots up to hard limit" do
    pool_name = :genai_fast_pool
    hard_limit = 5

    results =
      1..20
      |> Task.async_stream(fn _ -> AdmissionControl.try_admit_pool(pool_name, hard_limit) end,
        timeout: 5_000
      )
      |> Enum.map(fn {:ok, result} -> result end)

    admitted = Enum.count(results, &(&1 == :ok))
    rejected = Enum.count(results, &(&1 == {:error, :over_capacity}))

    assert admitted == hard_limit
    assert rejected == 15
    assert AdmissionControl.pool_count(pool_name) == hard_limit

    Enum.each(1..hard_limit, fn _ -> AdmissionControl.release_pool(pool_name) end)
    assert AdmissionControl.pool_count(pool_name) == 0
  end

  defp ensure_started(mod) do
    case Process.whereis(mod) do
      nil -> start_supervised!(mod)
      _pid -> :ok
    end
  end

  defp clear_tables do
    if :ets.whereis(:genai_counters) != :undefined do
      :ets.delete_all_objects(:genai_counters)
    end

    if :ets.whereis(:genai_breaker_snapshots) != :undefined do
      :ets.delete_all_objects(:genai_breaker_snapshots)
    end
  end
end
