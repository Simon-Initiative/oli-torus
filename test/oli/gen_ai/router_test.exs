defmodule Oli.GenAI.RouterTest do
  use ExUnit.Case, async: false

  alias Oli.GenAI.AdmissionControl
  alias Oli.GenAI.Router
  alias Oli.GenAI.Completions.{RegisteredModel, ServiceConfig}

  setup do
    ensure_started(AdmissionControl)
    clear_tables()
    :ok
  end

  test "routes to primary when healthy" do
    service_config = build_service_config(1)
    request_ctx = %{request_type: :generate}

    assert {:ok, plan} = Router.route(request_ctx, service_config)
    assert plan.selected_model.id == service_config.primary_model.id
    assert plan.tier == :primary
    assert plan.reason == :primary_normal
    assert plan.pool_name == :genai_slow_pool
  end

  test "routes to secondary when primary breaker is open" do
    service_config = build_service_config(2)
    request_ctx = %{request_type: :generate}

    AdmissionControl.put_breaker_snapshot(service_config.primary_model.id, %{state: :open})

    assert {:ok, plan} = Router.route(request_ctx, service_config)
    assert plan.selected_model.id == service_config.secondary_model.id
    assert plan.tier == :secondary
    assert plan.reason == :primary_breaker_open
  end

  test "routes to secondary when primary over capacity" do
    service_config =
      build_service_config(3,
        primary_model: %RegisteredModel{
          id: 31,
          name: "Primary",
          provider: :null,
          max_concurrent: 0
        }
      )

    request_ctx = %{request_type: :generate}

    assert {:ok, plan} = Router.route(request_ctx, service_config)
    assert plan.selected_model.id == service_config.secondary_model.id
    assert plan.tier == :secondary
    assert plan.reason == :primary_over_capacity
  end

  test "routes to secondary when service config soft limit reached" do
    service_config = build_service_config(7)
    request_ctx = %{request_type: :generate}

    AdmissionControl.increment_requests(service_config.id)
    AdmissionControl.increment_requests(service_config.id)

    assert {:ok, plan} = Router.route(request_ctx, service_config)
    assert plan.selected_model.id == service_config.secondary_model.id
    assert plan.tier == :secondary
    assert plan.reason == :service_config_soft_limit
  end

  test "rejects when service config hard limit reached" do
    service_config = build_service_config(8)
    request_ctx = %{request_type: :generate}

    AdmissionControl.increment_requests(service_config.id)
    AdmissionControl.increment_requests(service_config.id)
    AdmissionControl.increment_requests(service_config.id)

    assert {:error, :over_capacity} = Router.route(request_ctx, service_config)
  end

  test "rejects when secondary breaker is open and primary over capacity" do
    service_config =
      build_service_config(4,
        primary_model: %RegisteredModel{
          id: 41,
          name: "Primary",
          provider: :null,
          max_concurrent: 0
        }
      )

    request_ctx = %{request_type: :generate}

    AdmissionControl.put_breaker_snapshot(service_config.secondary_model.id, %{state: :open})

    assert {:error, :secondary_breaker_open} = Router.route(request_ctx, service_config)
  end

  test "routes to backup when primary and secondary breakers are open" do
    service_config = build_service_config(5)
    request_ctx = %{request_type: :generate}

    AdmissionControl.put_breaker_snapshot(service_config.primary_model.id, %{state: :open})
    AdmissionControl.put_breaker_snapshot(service_config.secondary_model.id, %{state: :open})

    assert {:ok, plan} = Router.route(request_ctx, service_config)
    assert plan.selected_model.id == service_config.backup_model.id
    assert plan.tier == :backup
    assert plan.reason == :backup_outage
  end

  test "rejects when backup breaker is open and primary and secondary are open" do
    service_config = build_service_config(6)
    request_ctx = %{request_type: :generate}

    AdmissionControl.put_breaker_snapshot(service_config.primary_model.id, %{state: :open})
    AdmissionControl.put_breaker_snapshot(service_config.secondary_model.id, %{state: :open})
    AdmissionControl.put_breaker_snapshot(service_config.backup_model.id, %{state: :open})

    assert {:error, :backup_breaker_open} = Router.route(request_ctx, service_config)
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
      backup_model: backup,
      routing_soft_limit: 2,
      routing_hard_limit: 3,
      routing_timeout_ms: 30_000,
      routing_connect_timeout_ms: 5_000
    }

    struct(base, overrides)
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
