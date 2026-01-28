defmodule Oli.GenAI.BreakerTest do
  use ExUnit.Case, async: false

  alias Oli.GenAI.{AdmissionControl, Breaker, BreakerSupervisor}

  setup do
    ensure_started(AdmissionControl)
    ensure_registry_started()
    ensure_started(BreakerSupervisor)
    clear_tables()
    :ok
  end

  test "opens breaker when error rate exceeds threshold" do
    model_id = 1
    thresholds = thresholds()

    Enum.each(1..3, fn _ ->
      Breaker.report(model_id, report(:ok, thresholds))
    end)

    Enum.each(1..2, fn _ ->
      Breaker.report(model_id, report(:error, thresholds))
    end)

    assert eventually(fn -> Breaker.status(model_id).breaker_state == :open end)
  end

  test "transitions to half_open and closes after probes succeed" do
    model_id = 2

    thresholds =
      thresholds(error_rate_threshold: 0.1, open_cooldown_ms: 0, half_open_probe_count: 2)

    Breaker.report(model_id, report(:error, thresholds))
    assert eventually(fn -> Breaker.status(model_id).breaker_state == :half_open end)

    Breaker.report(model_id, report(:ok, thresholds))
    assert Breaker.status(model_id).breaker_state == :half_open

    Breaker.report(model_id, report(:ok, thresholds))
    assert Breaker.status(model_id).breaker_state == :closed
  end

  test "half_open failure reopens breaker" do
    model_id = 3

    thresholds =
      thresholds(error_rate_threshold: 0.1, open_cooldown_ms: 0, half_open_probe_count: 1)

    reopen_thresholds =
      thresholds(error_rate_threshold: 0.1, open_cooldown_ms: 50, half_open_probe_count: 1)

    Breaker.report(model_id, report(:error, thresholds))
    assert eventually(fn -> Breaker.status(model_id).breaker_state == :half_open end)

    Breaker.report(model_id, report(:error, reopen_thresholds))
    assert eventually(fn -> Breaker.status(model_id).breaker_state == :open end)
  end

  test "opens breaker when 429 rate exceeds threshold" do
    model_id = 4
    thresholds = thresholds(rate_limit_threshold: 0.2, error_rate_threshold: 1.0)

    Enum.each(1..4, fn _ ->
      Breaker.report(model_id, report(:ok, thresholds))
    end)

    Breaker.report(model_id, report(:ok, thresholds, %{http_status: 429}))

    assert eventually(fn -> Breaker.status(model_id).breaker_state == :open end)
  end

  test "opens breaker when latency p95 exceeds threshold" do
    model_id = 5

    thresholds =
      thresholds(latency_p95_ms: 50, error_rate_threshold: 1.0, rate_limit_threshold: 1.0)

    Enum.each(1..5, fn _ ->
      Breaker.report(model_id, report(:ok, thresholds, %{latency_ms: 200}))
    end)

    assert eventually(fn -> Breaker.status(model_id).breaker_state == :open end)
  end

  defp thresholds(overrides \\ %{}) do
    base = %{
      error_rate_threshold: 0.2,
      rate_limit_threshold: 1.0,
      latency_p95_ms: 10_000,
      open_cooldown_ms: 10,
      half_open_probe_count: 1
    }

    Map.merge(base, Map.new(overrides))
  end

  defp report(outcome, thresholds, overrides \\ %{}) do
    base = %{
      outcome: outcome,
      http_status: if(outcome == :error, do: 500, else: 200),
      latency_ms: 10,
      thresholds: thresholds
    }

    Map.merge(base, overrides)
  end

  defp eventually(fun, attempts \\ 20)

  defp eventually(_fun, 0), do: false

  defp eventually(fun, attempts) do
    if fun.() do
      true
    else
      Process.sleep(10)
      eventually(fun, attempts - 1)
    end
  end

  defp ensure_started(mod) do
    case Process.whereis(mod) do
      nil -> start_supervised!(mod)
      _pid -> :ok
    end
  end

  defp ensure_registry_started do
    case Process.whereis(Oli.GenAI.BreakerRegistry) do
      nil -> start_supervised!({Registry, keys: :unique, name: Oli.GenAI.BreakerRegistry})
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
