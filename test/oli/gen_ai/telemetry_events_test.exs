defmodule Oli.GenAI.TelemetryEventsTest do
  use ExUnit.Case, async: false

  alias Oli.GenAI.{AdmissionControl, Breaker, BreakerSupervisor, Execution, Router}
  alias Oli.GenAI.Completions.{RegisteredModel, ServiceConfig}

  @router_decision [:oli, :genai, :router, :decision]
  @router_admission [:oli, :genai, :router, :admission]
  @provider_stop [:oli, :genai, :provider, :stop]
  @breaker_state_change [:oli, :genai, :breaker, :state_change]

  setup do
    ensure_started(AdmissionControl)
    ensure_registry_started()
    ensure_started(BreakerSupervisor)
    clear_tables()
    :ok
  end

  test "router emits decision and admission events for allowed request" do
    handler_id = unique_handler_id()
    attach(handler_id, [@router_decision, @router_admission])

    service_config = build_service_config(1)
    request_ctx = %{request_type: :generate}

    assert {:ok, _plan} = Router.route(request_ctx, service_config)

    assert_receive {:telemetry_event, @router_decision, measurements, metadata}
    assert is_integer(measurements.duration_ms)
    assert metadata.reason == :primary_normal
    assert metadata.service_config_id == service_config.id
    assert metadata.request_type == :generate
    assert metadata.tier == :primary
    assert metadata.pool_class == :slow
    assert metadata.pool_name == :genai_slow_pool

    assert_receive {:telemetry_event, @router_admission, measurements, metadata}
    assert measurements.admitted == 1
    assert metadata.tier == :primary
    assert metadata.pool_class == :slow
    assert metadata.pool_name == :genai_slow_pool

    detach(handler_id)
  end

  test "router emits rejection admission event when over capacity" do
    handler_id = unique_handler_id()
    attach(handler_id, [@router_decision, @router_admission])

    service_config =
      build_service_config(2,
        primary_model: %RegisteredModel{
          id: 21,
          name: "Primary",
          provider: :null,
          max_concurrent: 0
        },
        secondary_model: %RegisteredModel{
          id: 22,
          name: "Secondary",
          provider: :null,
          max_concurrent: 0
        }
      )

    request_ctx = %{request_type: :generate}

    assert {:error, :secondary_over_capacity} = Router.route(request_ctx, service_config)

    assert_receive {:telemetry_event, @router_decision, _measurements, metadata}
    assert metadata.reason == :secondary_over_capacity
    assert is_nil(metadata.tier)
    assert is_nil(metadata.pool_class)

    assert_receive {:telemetry_event, @router_admission, measurements, metadata}
    assert measurements.admitted == 0
    assert metadata.request_type == :generate
    assert is_nil(metadata.tier)
    assert is_nil(metadata.pool_class)

    detach(handler_id)
  end

  test "execution emits provider stop telemetry" do
    handler_id = unique_handler_id()
    attach(handler_id, [@provider_stop])

    service_config = build_service_config(3)
    request_ctx = %{request_type: :generate}

    assert {:ok, _} =
             Execution.generate(
               request_ctx,
               [],
               [],
               service_config,
               completions_mod: __MODULE__.FakeCompletions
             )

    assert_receive {:telemetry_event, @provider_stop, measurements, metadata}
    assert is_integer(measurements.duration_ms)
    assert metadata.outcome == :ok
    assert metadata.request_type == :generate
    assert metadata.service_config_id == service_config.id
    assert metadata.registered_model_id == service_config.primary_model.id
    assert metadata.tier == :primary
    assert metadata.pool_name == :genai_slow_pool
    assert metadata.pool_class == :slow
    assert metadata.reason == :primary_normal
    assert metadata.error_category == nil

    detach(handler_id)
  end

  test "breaker emits state change telemetry" do
    handler_id = unique_handler_id()
    attach(handler_id, [@breaker_state_change])

    model_id = 10

    thresholds =
      thresholds(error_rate_threshold: 0.0, open_cooldown_ms: 10, half_open_probe_count: 1)

    Breaker.report(model_id, report(:error, thresholds))

    assert_receive {:telemetry_event, @breaker_state_change, _measurements, metadata}
    assert metadata.state == :open
    assert metadata.reason == :threshold_exceeded

    detach(handler_id)
  end

  defmodule FakeCompletions do
    def generate(_messages, _functions, _model) do
      {:ok, %{response: "ok"}}
    end

    def stream(_messages, _functions, _model, _response_handler_fn), do: :ok
  end

  defp build_service_config(id, overrides \\ %{}) do
    primary = %RegisteredModel{id: id * 10 + 1, name: "Primary", provider: :null}
    secondary = %RegisteredModel{id: id * 10 + 2, name: "Secondary", provider: :null}
    backup = %RegisteredModel{id: id * 10 + 3, name: "Backup", provider: :null}

    base = %ServiceConfig{
      id: id,
      name: "ServiceConfig #{id}",
      primary_model: primary,
      secondary_model: secondary,
      backup_model: backup
    }

    struct(base, overrides)
  end

  defp thresholds(overrides) do
    base = %{
      error_rate_threshold: 0.2,
      rate_limit_threshold: 1.0,
      latency_p95_ms: 10_000,
      open_cooldown_ms: 10,
      half_open_probe_count: 1
    }

    Map.merge(base, Map.new(overrides))
  end

  defp report(outcome, thresholds) do
    %{
      outcome: outcome,
      http_status: if(outcome == :error, do: 500, else: 200),
      latency_ms: 10,
      thresholds: thresholds
    }
  end

  defp unique_handler_id do
    "genai-telemetry-test-#{System.unique_integer([:positive])}"
  end

  defp attach(handler_id, events) do
    parent = self()

    :telemetry.attach_many(
      handler_id,
      events,
      fn event_name, measurements, metadata, _ ->
        send(parent, {:telemetry_event, event_name, measurements, metadata})
      end,
      %{}
    )
  end

  defp detach(handler_id) do
    :telemetry.detach(handler_id)
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
