# Acceptance coverage: AC-004, AC-005, AC-006, AC-007.
defmodule Oli.GenAI.HealthMonitorTest do
  use ExUnit.Case, async: false
  alias Oli.GenAI.{HealthMonitor, Provider}
  alias Oli.GenAI.Completions.RegisteredModel

  test "probe evidence alone drives failure thresholds and independent recovery" do
    {monitor, _tasks, _config} = monitor()

    for count <- 1..3 do
      pid = next_probe(monitor, count == 1)
      send(pid, {:return, {:error, :upstream_unavailable}})
      eventually(fn -> HealthMonitor.snapshot(monitor).consecutive_failures == count end)
    end

    assert HealthMonitor.snapshot(monitor).observed == :unavailable
    send(monitor, {:request_outcome, :ok})
    assert HealthMonitor.snapshot(monitor).observed == :unavailable
    pid = next_probe(monitor)
    send(pid, {:return, :ok})
    eventually(fn -> HealthMonitor.snapshot(monitor).consecutive_successes == 1 end)
    assert HealthMonitor.snapshot(monitor).observed == :unavailable
    pid = next_probe(monitor)
    send(pid, {:return, :ok})
    eventually(fn -> HealthMonitor.snapshot(monitor).observed == :available end)
    assert HealthMonitor.snapshot(monitor).last_success != nil
  end

  test "one in-flight probe remains responsive and recurring probes run without request traffic" do
    {monitor, _, _} = monitor(%{probe_interval_ms: 20})
    pid = next_probe(monitor, true)
    assert HealthMonitor.snapshot(monitor).probe_in_flight
    HealthMonitor.check(monitor)
    refute_receive {:probe, _}, 40
    send(pid, {:return, :ok})
    assert_receive {:probe, next}, 2_000
    refute next == pid
    send(next, {:return, :ok})
  end

  test "deadline kills network work and records a bounded probe failure" do
    {monitor, _, _} = monitor(%{probe_deadline_ms: 60})
    pid = next_probe(monitor, true)
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}, 2_000
    eventually(fn -> HealthMonitor.snapshot(monitor).failure_category == :deadline_exceeded end)
    assert HealthMonitor.snapshot(monitor).consecutive_failures == 1
    refute HealthMonitor.snapshot(monitor).probe_in_flight
  end

  test "configuration rotation kills obsolete work and discards stale results and deadlines" do
    {monitor, _, config} = monitor()
    old = next_probe(monitor, true)
    old_task = :sys.get_state(monitor).task
    updated = put_in(config.provider.api_key, "rotated-secret")
    updated = put_in(updated.provider.config_version, 2)
    assert :ok = HealthMonitor.configure(monitor, updated)
    assert_receive {:probe, current}, 2_000
    refute current == old
    refute Process.alive?(old)
    send(monitor, {:probe_result, old_task.token, :ok})
    send(monitor, {:deadline, old_task.token})
    assert HealthMonitor.snapshot(monitor).observed == :unknown
    assert Process.alive?(current)
    send(current, {:return, :ok})
    eventually(fn -> HealthMonitor.snapshot(monitor).observed == :available end)
  end

  test "disabled monitoring bypasses observed health, preserves admin disablement and restarts unknown" do
    {monitor, _, config} = monitor(%{}, enabled: false)
    refute_receive {:probe, _}, 30

    assert %{monitoring_enabled: false, observed: :unknown, eligible: true} =
             HealthMonitor.snapshot(monitor)

    disabled = put_in(config.provider.enabled, false)
    assert :ok = HealthMonitor.configure(monitor, disabled)
    refute HealthMonitor.snapshot(monitor).eligible
    active = %{config | enabled: true}
    assert :ok = HealthMonitor.configure(monitor, active)
    assert_receive {:probe, pid}, 2_000
    assert HealthMonitor.snapshot(monitor).observed == :unknown
    send(pid, {:return, :ok})
    eventually(fn -> HealthMonitor.snapshot(monitor).observed == :available end)
  end

  test "missing model and deferred adapters expose configuration rather than healthy results" do
    {monitor, _, config} = monitor(%{}, model: nil)
    eventually(fn -> HealthMonitor.snapshot(monitor).failure_category == :missing_probe_model end)
    refute_receive {:probe, _}, 30
    assert HealthMonitor.snapshot(monitor).observed == :unknown
    assert :ok = HealthMonitor.configure(monitor, put_in(config.provider.adapter, :claude))
    refute HealthMonitor.snapshot(monitor).eligible
  end

  test "local pool contention never changes observed Provider health" do
    {monitor, _, _} = monitor()
    pid = next_probe(monitor, true)
    send(pid, {:return, :ok})
    eventually(fn -> HealthMonitor.snapshot(monitor).observed == :available end)
    pid = next_probe(monitor)
    send(pid, {:return, {:local_error, :busy}})
    eventually(fn -> HealthMonitor.snapshot(monitor).failure_category == :busy end)
    assert HealthMonitor.snapshot(monitor).observed == :available
    assert HealthMonitor.snapshot(monitor).consecutive_failures == 0
  end

  test "task crashes count as synthetic probe failures without crashing the monitor" do
    {monitor, _, _} = monitor()
    pid = next_probe(monitor, true)
    send(pid, :crash)
    eventually(fn -> HealthMonitor.snapshot(monitor).failure_category == :task_exit end)
    assert Process.alive?(monitor)
  end

  test "killing a monitor also kills its in-flight probe before a replacement starts" do
    {monitor, tasks, config} = monitor()
    pid = next_probe(monitor, true)
    ref = Process.monitor(pid)
    Process.exit(monitor, :kill)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 2_000
    parent = self()

    replacement =
      start_supervised!(
        Supervisor.child_spec(
          {HealthMonitor,
           config: config, task_supervisor: tasks, probe: probe(parent), jitter_ms: 0},
          id: make_ref(),
          restart: :temporary
        )
      )

    assert_receive {:probe, current}, 2_000
    assert Process.alive?(replacement)
    send(current, {:return, :ok})
  end

  test "probe task supervisor capacity skips a check without manufacturing an outage" do
    {monitor, tasks, config} = monitor()
    pid = next_probe(monitor, true)
    parent = self()

    other =
      start_supervised!(
        Supervisor.child_spec(
          {HealthMonitor,
           config: config, task_supervisor: tasks, probe: probe(parent), jitter_ms: 0},
          id: make_ref(),
          restart: :temporary
        )
      )

    refute_receive {:probe, _}, 40
    assert HealthMonitor.snapshot(other).consecutive_failures == 0
    send(pid, {:return, :ok})
    eventually(fn -> Task.Supervisor.children(tasks) == [] end)
    HealthMonitor.check(other)
    assert_receive {:probe, fresh}, 2_000
    send(fresh, {:return, :ok})
    eventually(fn -> HealthMonitor.snapshot(other).observed == :available end)
  end

  defp monitor(overrides \\ %{}, opts \\ []) do
    tasks = start_supervised!({Task.Supervisor, max_children: 1})

    provider =
      struct!(
        Provider,
        Map.merge(
          %{
            id: 17,
            name: "test",
            adapter: :open_ai,
            base_url: "http://127.0.0.1:9999",
            api_key: "secret",
            probe_interval_ms: 60_000,
            probe_failure_interval_ms: 60_000,
            probe_deadline_ms: 2_000
          },
          overrides
        )
      )

    model =
      Keyword.get(opts, :model, %RegisteredModel{
        id: 18,
        provider: :open_ai,
        model: "test",
        health_check: true
      })

    config = %{provider: provider, model: model, enabled: Keyword.get(opts, :enabled, true)}
    parent = self()

    monitor =
      start_supervised!(
        Supervisor.child_spec(
          {HealthMonitor,
           config: config, task_supervisor: tasks, probe: probe(parent), jitter_ms: 0},
          restart: :temporary
        )
      )

    {monitor, tasks, config}
  end

  defp probe(parent) do
    fn _, _ ->
      send(parent, {:probe, self()})

      receive do
        {:return, result} -> result
        :crash -> Process.exit(self(), :kill)
      end
    end
  end

  defp next_probe(monitor, initial \\ false) do
    case initial do
      true -> :ok
      false -> HealthMonitor.check(monitor)
    end

    assert_receive {:probe, pid}, 2_000
    pid
  end

  defp eventually(fun, attempts \\ 100)
  defp eventually(fun, 0), do: assert(fun.())

  defp eventually(fun, attempts) do
    case fun.() do
      true ->
        :ok

      false ->
        Process.sleep(10)
        eventually(fun, attempts - 1)
    end
  end
end
