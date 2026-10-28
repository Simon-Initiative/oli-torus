# Acceptance coverage: AC-004, AC-005, AC-007, AC-008, AC-009, AC-010, AC-011, AC-012, AC-013, AC-016, AC-017, AC-019, AC-021.
defmodule Oli.GenAI.RouterTest do
  use ExUnit.Case, async: false

  alias Oli.GenAI.{
    Execution,
    HealthMonitor,
    PoolManager,
    Provider,
    Router,
    Runtime,
    TransportPool
  }

  alias Oli.GenAI.Completions.{Message, RegisteredModel, ServiceConfig}

  setup do
    parent = self()

    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true, ip: {127, 0, 0, 1}])

    {:ok, {_, port}} = :inet.sockname(listener)
    server = spawn_link(fn -> accept(listener, parent) end)

    on_exit(fn ->
      :gen_tcp.close(listener)
      Process.unlink(server)
      Process.exit(server, :kill)
    end)

    provider = %Provider{
      id: 1,
      name: "Main",
      adapter: :open_ai,
      base_url: "http://127.0.0.1:#{port}",
      api_key: "provider-secret",
      config_version: 1,
      enabled: true,
      failure_threshold: 1,
      probe_interval_ms: 60_000,
      probe_failure_interval_ms: 60_000
    }

    backup_provider = %{provider | id: 2, name: "Backup", api_key: "backup-secret"}

    primary = %RegisteredModel{
      id: 11,
      provider_id: 1,
      model: "primary",
      timeout: 1000,
      recv_timeout: 2000
    }

    secondary = %{primary | id: 12, model: "secondary"}
    backup = %{primary | id: 13, provider_id: 2, model: "backup"}

    config = %ServiceConfig{
      id: 7,
      primary_model: primary,
      secondary_model: secondary,
      backup_model: backup,
      primary_pool_capacity: 1,
      secondary_pool_capacity: 1,
      backup_pool_capacity: 1
    }

    loaded = %{
      providers: [
        %{provider: provider, model: primary, models: [primary, secondary]},
        %{provider: backup_provider, model: backup, models: [backup]}
      ],
      service_configs: [config]
    }

    source = start_supervised!({Agent, fn -> loaded end})
    manager = start_supervised!({PoolManager, name: nil, namespace: make_ref(), poll_ms: 10})
    tasks = start_supervised!({Task.Supervisor, max_children: 4})

    runtime =
      start_supervised!(
        {Runtime,
         name: nil,
         source: fn -> Agent.get(source, & &1) end,
         pool_manager: manager,
         task_supervisor: tasks,
         enabled: true,
         probe: fn _, _ -> :ok end,
         jitter_ms: 0,
         interval_ms: 60_000}
      )

    :ok = Runtime.reconcile(runtime)

    %{
      config: config,
      ctx: %{runtime: runtime},
      runtime: runtime,
      source: source,
      manager: manager,
      url: provider.base_url
    }
  end

  test "selection observes occupancy without reserving; full primary selects secondary, both full busy",
       c do
    assert {:ok, a} = Router.route(c.ctx, c.config)
    assert {:ok, b} = Router.route(c.ctx, c.config)
    assert a.tier == :primary and b.tier == :primary
    assert a.pool == b.pool
    {:ok, one} = TransportPool.connect(a.pool, c.url)
    assert {:ok, secondary} = Router.route(c.ctx, c.config)
    assert secondary.tier == :secondary
    {:ok, two} = TransportPool.connect(secondary.pool, c.url)
    assert {:error, :busy} = Router.route(c.ctx, c.config)
    :hackney.close(one)
    :hackney.close(two)
    empty(c)
  end

  test "missing secondary returns busy; backup is isolated and never capacity overflow", c do
    change(c, fn l -> %{l | service_configs: [%{c.config | secondary_model: nil}]} end)
    {:ok, plan} = Router.route(c.ctx, c.config)
    {:ok, ref} = TransportPool.connect(plan.pool, c.url)
    assert {:error, :busy} = Router.route(c.ctx, c.config)
    assert {:ok, backup} = Router.backup(c.ctx, c.config, 1)
    assert backup.tier == :backup and backup.pool != plan.pool
    :hackney.close(ref)
  end

  test "separate ServiceConfigs keep independent pools for the same model", c do
    other = %{c.config | id: 8}
    change(c, fn l -> %{l | service_configs: [c.config, other]} end)
    {:ok, first} = Router.route(c.ctx, c.config)
    {:ok, second} = Router.route(c.ctx, other)
    refute first.pool == second.pool
    {:ok, ref} = TransportPool.connect(first.pool, c.url)
    assert {:ok, %{tier: :primary}} = Router.route(c.ctx, other)
    :hackney.close(ref)
  end

  test "independent probe outage selects backup; backup saturation returns busy", c do
    monitor = :sys.get_state(c.runtime).monitors[1]
    state = :sys.get_state(monitor)

    :ok =
      HealthMonitor.configure(monitor, %{
        state.config
        | provider: %{state.config.provider | config_version: 2}
      })

    # Only a synthetic probe result determines unavailability.
    :sys.replace_state(monitor, fn s ->
      %{s | probe: fn _, _ -> {:error, :upstream_unavailable} end}
    end)

    HealthMonitor.check(monitor)
    eventually(fn -> Runtime.snapshot(c.runtime).providers[1].observed == :unavailable end)
    assert {:ok, %{tier: :backup} = plan} = Router.route(c.ctx, c.config)
    {:ok, ref} = TransportPool.connect(plan.pool, c.url)
    assert {:error, :busy} = Router.route(c.ctx, c.config)
    :hackney.close(ref)
  end

  test "real generate uses Provider credentials and pre-output 503 retries backup exactly once",
       c do
    task = Task.async(fn -> Execution.generate_with_metadata(c.ctx, messages(), [], c.config) end)
    assert_receive {:request, first, headers, %{"model" => "primary"}}, 2000
    assert headers =~ "Bearer provider-secret"
    send(first, {:response, 503, "unavailable"})
    assert_receive {:request, second, headers, %{"model" => "backup"}}, 2000
    assert headers =~ "Bearer backup-secret"
    send(second, {:response, 200, completion("backup worked")})

    assert {:ok, %{content: "backup worked", metadata: %{registered_model_id: 13}}} =
             Task.await(task)

    refute_receive {:request, _, _, _}, 20
    assert Runtime.snapshot(c.runtime).providers[1].observed in [:available, :unknown]
    empty(c)
  end

  test "HTTP 429 and invalid input do not retry backup", c do
    for status <- [400, 401, 429] do
      task = Task.async(fn -> Execution.generate(c.ctx, messages(), [], c.config) end)
      assert_receive {:request, server, _, _}, 2000
      send(server, {:response, status, "private upstream error"})
      assert {:error, %{http_status: ^status}} = Task.await(task)
      refute_receive {:request, _, _, _}, 20
    end

    empty(c)
  end

  test "a failed backup is never retried", c do
    task = Task.async(fn -> Execution.generate(c.ctx, messages(), [], c.config) end)

    for model <- ["primary", "backup"] do
      assert_receive {:request, server, _, %{"model" => ^model}}, 2000
      send(server, {:response, 500, "unavailable"})
    end

    assert {:error, %{http_status: 500}} = Task.await(task)
    refute_receive {:request, _, _, _}, 20
    empty(c)
  end

  test "a checkout race returns local busy without another secondary or backup attempt", c do
    parent = self()
    before = Runtime.snapshot(c.runtime).providers[1].consecutive_failures

    task =
      Task.async(fn ->
        Execution.generate(c.ctx, messages(), [], c.config,
          on_plan: fn plan ->
            {:ok, ref} = TransportPool.connect(plan.pool, c.url)
            send(parent, {:occupied_after_selection, ref})
          end
        )
      end)

    assert_receive {:occupied_after_selection, _}, 2000
    started = System.monotonic_time(:millisecond)
    assert {:error, :busy} = Task.await(task, 2500)
    assert System.monotonic_time(:millisecond) - started < 2000
    refute_receive {:request, _, _, _}, 20
    assert Runtime.snapshot(c.runtime).providers[1].consecutive_failures == before
    empty(c)
  end

  test "selected checkout contention times out locally and cannot select secondary afterward",
       c do
    parent = self()
    opts = [on_plan: fn plan -> send(parent, {:selected_pool, plan.pool}) end]
    # Occupy after both requests have selected but before the second network attempt.
    task1 = Task.async(fn -> Execution.generate(c.ctx, messages(), [], c.config, opts) end)
    assert_receive {:selected_pool, pool}
    assert_receive {:request, server, _, _}, 2000

    # Router observes full -> secondary normally. Test checkout race directly on the already-selected pool.
    task2 = Task.async(fn -> TransportPool.connect(pool, c.url, checkout_timeout: 100) end)
    eventually(fn -> TransportPool.snapshot(pool).current.queue_depth == 1 end)
    assert {:error, :busy} = Task.await(task2, 2000)
    assert TransportPool.snapshot(pool).current.queue_depth == 0
    refute_receive {:request, _, _, _}, 20
    send(server, {:response, 200, completion("ok")})
    assert {:ok, "ok"} = Task.await(task1)
    empty(c)
  end

  test "completed streaming retains occupancy during consumption and reclaims it", c do
    {task, server} = stream(c)
    send(server, {:chunk, sse(%{choices: [%{delta: %{content: "hello"}}]})})
    assert_receive {:chunk, {:tokens_received, "hello"}}
    assert PoolManager.snapshot(c.manager).pools[{7, :primary}].current.checked_out == 1
    send(server, {:chunk, sse(%{choices: [%{finish_reason: "stop", delta: %{}}]})})
    assert :ok = Task.await(task)
    empty(c)
  end

  test "truncation and upstream SSE errors after content or tool fragments interrupt without backup",
       c do
    for delta <- [
          %{content: "partial"},
          %{tool_calls: [%{id: "x", function: %{name: "f", arguments: "{"}}]}
        ] do
      {task, server} = stream(c)
      send(server, {:chunk, sse(%{choices: [%{delta: delta}]})})
      assert_receive {:chunk, _}, 1000
      send(server, :finish)
      assert {:error, :interrupted_stream} = Task.await(task)
      refute_receive {:request, _, _, _}, 20
      empty(c)
    end

    {task, server} = stream(c)
    send(server, {:chunk, sse(%{choices: [%{delta: %{content: "partial"}}]})})
    assert_receive {:chunk, _}
    send(server, {:chunk, sse(%{error: %{message: "sensitive"}})})
    assert {:error, :interrupted_stream} = Task.await(task)
    empty(c)
  end

  test "kill, total deadline, and callback exception reclaim live streaming connections", c do
    {task, _} = stream(c)
    Process.unlink(task.pid)
    Process.exit(task.pid, :kill)
    empty(c)
    {task, _} = stream(c, total_timeout_ms: 100)
    assert {:error, :inference_deadline} = Task.await(task)
    empty(c)
    {task, server} = stream(c, [], fn _ -> throw(:callback_failed) end)
    send(server, {:chunk, sse(%{choices: [%{delta: %{content: "hello"}}]})})
    assert {:caught, :callback_failed} = Task.await(task)
    empty(c)
  end

  test "generation replacement preserves active streams and rejects stale credentials even at the same origin",
       c do
    {:ok, stale} = Router.route(c.ctx, c.config)
    {old_task, old_server} = stream(c)

    change(c, fn l ->
      providers =
        Enum.map(l.providers, fn entry ->
          %{entry | provider: %{entry.provider | config_version: 2, api_key: "rotated"}}
        end)

      %{l | providers: providers, service_configs: [%{c.config | primary_pool_capacity: 2}]}
    end)

    assert {:error, :stale_configuration} =
             TransportPool.connect(stale.pool, c.url, expected_signature: stale.signature)

    {new_task, new_server} = stream(c)
    pool = PoolManager.snapshot(c.manager).pools[{7, :primary}]
    assert pool.current.capacity == 2 and pool.current.checked_out == 1
    assert Enum.any?(pool.retired, &(&1.checked_out == 1))

    for {task, server} <- [{old_task, old_server}, {new_task, new_server}] do
      send(server, {:chunk, sse(%{choices: [%{finish_reason: "stop", delta: %{}}]})})
      assert :ok = Task.await(task)
    end

    empty(c)
  end

  test "disabled monitoring preserves primary-secondary pool routing and administrative disablement",
       c do
    :sys.replace_state(c.runtime, &%{&1 | enabled: false})
    assert :ok = Runtime.reconcile(c.runtime)
    {:ok, plan} = Router.route(c.ctx, c.config)
    {:ok, ref} = TransportPool.connect(plan.pool, c.url)
    assert {:ok, %{tier: :secondary}} = Router.route(c.ctx, c.config)
    :hackney.close(ref)

    change(c, fn l ->
      %{
        l
        | providers:
            Enum.map(l.providers, fn entry ->
              case entry.provider.id do
                1 -> %{entry | provider: %{entry.provider | enabled: false}}
                _ -> entry
              end
            end)
      }
    end)

    assert {:ok, %{tier: :backup}} = Router.route(c.ctx, c.config)
  end

  test "stale health and missing configuration do not masquerade as observed outages", c do
    eventually(fn -> Runtime.snapshot(c.runtime).providers[1].observed == :available end)
    monitor = :sys.get_state(c.runtime).monitors[1]

    :sys.replace_state(monitor, fn state ->
      %{state | completed_at: System.monotonic_time(:millisecond) - 200_000}
    end)

    assert {:error, :provider_ineligible} = Router.route(c.ctx, c.config)
    assert {:error, :configuration_unavailable} = Router.route(c.ctx, %{c.config | id: 999})
  end

  test "kill while queued removes pending checkout and associated connections", c do
    parent = self()

    task =
      Task.async(fn ->
        Execution.generate(c.ctx, messages(), [], c.config,
          on_plan: fn plan ->
            {:ok, _ref} = TransportPool.connect(plan.pool, c.url)
            send(parent, {:queued_pool, plan.pool})
          end
        )
      end)

    assert_receive {:queued_pool, pool}, 2000
    eventually(fn -> TransportPool.snapshot(pool).current.queue_depth == 1 end)
    Process.unlink(task.pid)
    Process.exit(task.pid, :kill)
    empty(c)
  end

  test "inactivity after output interrupts while pre-output inactivity may try backup once", c do
    config = %{c.config | primary_model: %{c.config.primary_model | recv_timeout: 80}}
    change(c, fn l -> %{l | service_configs: [config]} end)
    {task, server} = stream(c)
    send(server, {:chunk, sse(%{choices: [%{delta: %{content: "partial"}}]})})
    assert_receive {:chunk, {:tokens_received, "partial"}}
    assert {:error, :interrupted_stream} = Task.await(task)
    refute_receive {:request, _, _, _}, 20
    empty(c)
    {task, _server} = stream(c)
    assert_receive {:request, backup, _, %{"model" => "backup"}}, 2000
    send(backup, :stream)

    send(
      backup,
      {:chunk, sse(%{choices: [%{delta: %{content: "recovered"}, finish_reason: "stop"}]})}
    )

    assert :ok = Task.await(task)
    assert_receive {:chunk, {:tokens_received, "recovered"}}
    empty(c)
  end

  test "malformed and truncated pre-output SSE return errors with no automatic retry", c do
    for data <- ["data: invalid-json\n\n", "data: [DONE]\n\n"] do
      {task, server} = stream(c)
      send(server, {:chunk, data})
      assert {:error, reason} = Task.await(task)
      assert reason in [:invalid_response, :truncated_stream]
      refute_receive {:request, _, _, _}, 20
      empty(c)
    end
  end

  test "routing stays responsive while configuration reload is blocked", c do
    parent = self()

    :sys.replace_state(c.runtime, fn state ->
      %{
        state
        | source: fn ->
            send(parent, :reload_blocked)

            receive do
              :continue_reload -> Agent.get(c.source, & &1)
            end
          end
      }
    end)

    send(c.runtime, :reconcile)
    assert_receive :reload_blocked
    task = Task.async(fn -> Router.route(c.ctx, c.config) end)
    assert {:ok, %{tier: :primary}} = Task.await(task, 200)
    send(c.runtime, :continue_reload)
    # Wait until the current reload finishes, without starting another blocking reload.
    assert %{observe_only: false} = Runtime.snapshot(c.runtime)
  end

  test "Claude cannot fall back to legacy dispatch", c do
    change(c, fn loaded ->
      %{
        loaded
        | providers:
            Enum.map(loaded.providers, fn entry ->
              %{entry | provider: %{entry.provider | adapter: :claude}}
            end)
      }
    end)

    assert {:error, :unsupported_adapter} = Router.route(c.ctx, c.config)
  end

  test "missing runtime configuration never falls back to caller models", c do
    assert {:error, :configuration_unavailable} =
             Router.route(%{runtime: :missing_genai_runtime}, c.config)
  end

  test "the deadline reclaims a checkout even while its callback remains blocked", c do
    parent = self()

    {task, server} =
      stream(c, [total_timeout_ms: 100], fn _ ->
        send(parent, :callback_blocked)

        receive do
          :continue_callback -> :ok
        end
      end)

    send(server, {:chunk, sse(%{choices: [%{delta: %{content: "hello"}}]})})
    assert_receive :callback_blocked
    empty(c)
    assert Process.alive?(task.pid)
    send(task.pid, :continue_callback)
    assert {:error, :interrupted_stream} = Task.await(task)
  end

  test "initial role with null content is ignored and final content is retained", c do
    {task, server} = stream(c)
    send(server, {:chunk, sse(%{choices: [%{delta: %{role: "assistant", content: nil}}]})})
    refute_receive {:chunk, _}, 20
    send(server, {:chunk, sse(%{choices: [%{delta: %{content: "last"}, finish_reason: "stop"}]})})
    assert :ok = Task.await(task)
    assert_receive {:chunk, {:tokens_received, "last"}}
    assert_receive {:chunk, {:tokens_finished}}
    empty(c)
  end

  test "oversized complete SSE events are rejected before exposure, including split input", c do
    oversized = sse(%{choices: [%{delta: %{content: String.duplicate("x", 1_048_576)}}]})

    for chunks <- [
          [oversized],
          [
            binary_part(oversized, 0, 500_000),
            binary_part(oversized, 500_000, byte_size(oversized) - 500_000)
          ]
        ] do
      {task, server} = stream(c)
      for chunk <- chunks, do: send(server, {:chunk, chunk})
      assert {:error, :response_too_large} = Task.await(task)
      refute_receive {:chunk, _}, 20
      empty(c)
    end
  end

  test "model and same-origin endpoint edits invalidate stale selections", c do
    {:ok, original} = Router.route(c.ctx, c.config)
    edited = %{c.config | primary_model: %{c.config.primary_model | model: "new-model"}}
    change(c, fn l -> %{l | service_configs: [edited]} end)

    assert {:error, :stale_configuration} =
             TransportPool.connect(original.pool, c.url, expected_signature: original.signature)

    {:ok, next} = Router.route(c.ctx, c.config)

    change(c, fn l ->
      %{
        l
        | providers:
            Enum.map(l.providers, fn entry ->
              %{
                entry
                | provider: %{
                    entry.provider
                    | base_url: entry.provider.base_url <> "/new-endpoint"
                  }
              }
            end)
      }
    end)

    assert {:error, :stale_configuration} =
             TransportPool.connect(next.pool, c.url, expected_signature: next.signature)
  end

  test "backup absence or ineligibility is bounded and the total deadline spans both attempts",
       c do
    change(c, fn l -> %{l | service_configs: [%{c.config | backup_model: nil}]} end)
    assert {:error, :backup_unavailable} = Router.backup(c.ctx, c.config, 1)

    change(c, fn l ->
      %{
        l
        | service_configs: [c.config],
          providers:
            Enum.map(l.providers, fn e ->
              case e.provider.id do
                2 -> %{e | provider: %{e.provider | enabled: false}}
                _ -> e
              end
            end)
      }
    end)

    assert {:error, :backup_unavailable} = Router.backup(c.ctx, c.config, 1)

    change(c, fn l ->
      %{
        l
        | providers:
            Enum.map(l.providers, fn e -> %{e | provider: %{e.provider | enabled: true}} end)
      }
    end)

    started = System.monotonic_time(:millisecond)

    task =
      Task.async(fn ->
        Execution.generate(c.ctx, messages(), [], c.config, total_timeout_ms: 600)
      end)

    assert_receive {:request, primary, _, %{"model" => "primary"}}, 2000
    Process.sleep(350)
    send(primary, {:response, 503, "unavailable"})
    assert_receive {:request, _, _, %{"model" => "backup"}}, 2000
    assert {:error, :inference_deadline} = Task.await(task, 400)
    assert System.monotonic_time(:millisecond) - started < 850
    empty(c)
  end

  test "checkout telemetry separates native timeout, cancellation and startup deadline", c do
    handler = {__MODULE__, make_ref()}

    :ok =
      :telemetry.attach(handler, [:oli, :genai, :pool, :checkout], &__MODULE__.record/4, self())

    on_exit(fn -> :telemetry.detach(handler) end)
    {:ok, plan} = Router.route(c.ctx, c.config)
    {:ok, ref} = TransportPool.connect(plan.pool, c.url)

    assert_receive {:checkout, %{startup_duration_ms: duration},
                    %{cause: :ok, timing_scope: :checkout_and_connect}}

    assert is_integer(duration)
    task = Task.async(fn -> TransportPool.connect(plan.pool, c.url, checkout_timeout: 50) end)
    assert {:error, :busy} = Task.await(task)
    assert_receive {:checkout, %{checkout_timeout_wait_ms: wait}, %{cause: :checkout_timeout}}
    assert wait >= 40 and wait < 1000

    task =
      Task.async(fn ->
        TransportPool.connect(plan.pool, c.url,
          deadline: System.monotonic_time(:millisecond) + 30
        )
      end)

    assert {:error, :busy} = Task.await(task)
    assert_receive {:checkout, _, %{cause: cause}}
    # A native checkout shortened to the total startup deadline may win the same boundary race.
    assert cause in [:startup_deadline, :checkout_timeout]
    task = Task.async(fn -> TransportPool.connect(plan.pool, c.url) end)
    eventually(fn -> TransportPool.snapshot(plan.pool).current.queue_depth == 1 end)
    Process.unlink(task.pid)
    Process.exit(task.pid, :kill)
    assert_receive {:checkout, measurements, %{cause: :owner_cancelled}}
    refute Map.has_key?(measurements, :checkout_timeout_wait_ms)
    :hackney.close(ref)
    empty(c)
  end

  def record(_, measurements, metadata, owner),
    do: send(owner, {:checkout, measurements, metadata})

  test "administrative inference uses its own pool or the supplied ServiceConfig pool (AC-017)",
       c do
    {:ok, plan} = Router.route(c.ctx, c.config)
    {:ok, ref} = TransportPool.connect(plan.pool, c.url)

    task =
      Task.async(fn ->
        Oli.GenAI.Administrative.generate(messages(), [], c.config.primary_model,
          runtime: c.runtime
        )
      end)

    assert_receive {:request, server, headers, %{"model" => "primary"}}, 2000
    assert headers =~ "Bearer provider-secret"

    assert Enum.any?(PoolManager.snapshot(c.manager).pools, fn {key, pool} ->
             match?({:administrative, _, _}, key) and pool.current.checked_out == 1
           end)

    send(server, {:response, 200, completion("admin")})
    assert {:ok, "admin"} = Task.await(task)

    task =
      Task.async(fn ->
        Oli.GenAI.Administrative.generate(messages(), [], c.config.primary_model,
          runtime: c.runtime,
          service_config: c.config
        )
      end)

    assert_receive {:request, server, _, %{"model" => "secondary"}}, 2000
    assert PoolManager.snapshot(c.manager).pools[{7, :secondary}].current.checked_out == 1
    send(server, {:response, 200, completion("production")})
    assert {:ok, "production"} = Task.await(task)
    :hackney.close(ref)
    empty(c)
  end

  test "administrative saturation is bounded and isolated from production (AC-017)", c do
    requests =
      for _ <- 1..4 do
        task =
          Task.async(fn ->
            Oli.GenAI.Administrative.generate(messages(), [], c.config.primary_model,
              runtime: c.runtime
            )
          end)

        assert_receive {:request, server, _, _}, 2000
        {task, server}
      end

    assert {:error, :busy} =
             Oli.GenAI.Administrative.generate(messages(), [], c.config.primary_model,
               runtime: c.runtime
             )

    task = Task.async(fn -> Execution.generate(c.ctx, messages(), [], c.config) end)
    assert_receive {:request, server, _, %{"model" => "primary"}}, 2000
    send(server, {:response, 200, completion("isolated")})
    assert {:ok, "isolated"} = Task.await(task)

    for {task, server} <- requests do
      send(server, {:response, 200, completion("admin")})
      assert {:ok, "admin"} = Task.await(task)
    end

    empty(c)
  end

  test "real independent probes recover main during backup streaming despite production saturation (AC-005, AC-007, AC-021)",
       c do
    {:ok, primary} = Router.route(c.ctx, c.config)
    {:ok, ref} = TransportPool.connect(primary.pool, c.url)
    monitor = :sys.get_state(c.runtime).monitors[1]

    :sys.replace_state(monitor, fn state ->
      %{
        state
        | probe: fn provider, model ->
            Oli.GenAI.HealthProbe.run(provider, model, c.manager)
          end
      }
    end)

    HealthMonitor.check(monitor)
    assert_receive {:request, probe, _, _}, 2000
    send(probe, {:response, 503, "outage"})
    eventually(fn -> Runtime.snapshot(c.runtime).providers[1].observed == :unavailable end)
    {task, backup} = stream(c)
    send(backup, {:chunk, sse(%{choices: [%{delta: %{content: "backup"}}]})})
    assert_receive {:chunk, {:tokens_received, "backup"}}

    for _ <- 1..2 do
      HealthMonitor.check(monitor)
      assert_receive {:request, probe, _, _}, 2000

      send(
        probe,
        {:response, 200,
         Jason.encode!(%{choices: [%{finish_reason: "stop", message: %{content: "OK"}}]})}
      )

      eventually(fn -> not Runtime.snapshot(c.runtime).providers[1].probe_in_flight end)
    end

    assert Runtime.snapshot(c.runtime).providers[1].observed == :available
    assert {:ok, %{tier: :secondary}} = Router.route(c.ctx, c.config)
    :hackney.close(ref)
    assert {:ok, %{tier: :primary}} = Router.route(c.ctx, c.config)
    send(backup, {:chunk, sse(%{choices: [%{finish_reason: "stop", delta: %{}}]})})
    assert :ok = Task.await(task)
    empty(c)
  end

  defp messages, do: [%Message{role: :user, content: "hello"}]
  defp completion(text), do: Jason.encode!(%{choices: [%{message: %{content: text}}]})
  defp sse(value), do: "data: " <> Jason.encode!(value) <> "\n\n"

  defp change(c, fun) do
    Agent.update(c.source, fun)
    assert :ok = Runtime.reconcile(c.runtime)
  end

  defp stream(c, opts \\ [], handler \\ nil) do
    parent = self()
    handler = handler || fn event -> send(parent, {:chunk, event}) end

    task =
      Task.async(fn ->
        try do
          Execution.stream(c.ctx, messages(), [], c.config, handler, opts)
        catch
          :throw, reason -> {:caught, reason}
        end
      end)

    assert_receive {:request, server, _, _}, 2000
    send(server, :stream)
    {task, server}
  end

  defp empty(c) do
    eventually(fn ->
      Enum.all?(PoolManager.snapshot(c.manager).pools, fn {_, pool} ->
        Enum.all?(
          List.wrap(pool.current) ++ pool.retired,
          &(&1.checked_out == 0 and &1.queue_depth == 0)
        )
      end)
    end)
  end

  defp eventually(fun, n \\ 150)
  defp eventually(fun, 0), do: assert(fun.())

  defp eventually(fun, n) do
    case fun.() do
      true ->
        :ok

      false ->
        Process.sleep(10)
        eventually(fun, n - 1)
    end
  end

  defp accept(listener, parent) do
    case :gen_tcp.accept(listener) do
      {:ok, socket} ->
        pid =
          spawn_link(fn ->
            receive do
              :ready -> serve(socket, parent)
            end
          end)

        :ok = :gen_tcp.controlling_process(socket, pid)
        send(pid, :ready)
        accept(listener, parent)

      {:error, :closed} ->
        :ok
    end
  end

  defp serve(socket, parent) do
    with {:ok, header, body} <- headers(socket, ""),
         [_, length] <- Regex.run(~r/content-length:\s*(\d+)/i, header) do
      missing = String.to_integer(length) - byte_size(body)

      rest =
        case missing > 0 do
          true ->
            case :gen_tcp.recv(socket, missing, 3000) do
              {:ok, b} -> b
              _ -> ""
            end

          false ->
            ""
        end

      send(parent, {:request, self(), header, Jason.decode!(body <> rest)})

      receive do
        {:response, status, response} ->
          :gen_tcp.send(
            socket,
            "HTTP/1.1 #{status} Response\r\ncontent-length: #{byte_size(response)}\r\nconnection: close\r\n\r\n#{response}"
          )

        :stream ->
          :gen_tcp.send(
            socket,
            "HTTP/1.1 200 OK\r\ncontent-type: text/event-stream\r\ntransfer-encoding: chunked\r\nconnection: close\r\n\r\n"
          )

          chunks(socket)
      after
        5000 -> :ok
      end
    end

    :gen_tcp.close(socket)
  end

  defp chunks(socket) do
    receive do
      {:chunk, data} ->
        case :gen_tcp.send(
               socket,
               Integer.to_string(byte_size(data), 16) <> "\r\n" <> data <> "\r\n"
             ) do
          :ok -> chunks(socket)
          _ -> :ok
        end

      :finish ->
        :gen_tcp.send(socket, "0\r\n\r\n")
    after
      5000 -> :ok
    end
  end

  defp headers(socket, acc) do
    case :binary.split(acc, "\r\n\r\n") do
      [head, body] ->
        {:ok, head, body}

      _ ->
        case :gen_tcp.recv(socket, 0, 3000) do
          {:ok, bytes} -> headers(socket, acc <> bytes)
          error -> error
        end
    end
  end
end
