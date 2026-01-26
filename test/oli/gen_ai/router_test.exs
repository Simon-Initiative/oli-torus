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

  test "routes to primary under soft limit" do
    service_config = build_service_config(1)
    request_ctx = %{request_type: :generate}

    assert {:ok, plan} = Router.route(request_ctx, service_config)
    assert plan.selected_model.id == service_config.primary_model.id
    assert plan.reason == :primary_normal
  end

  test "routes to backup when soft limit exceeded" do
    service_config = build_service_config(2)
    request_ctx = %{request_type: :generate}

    AdmissionControl.increment_requests(service_config.id)
    AdmissionControl.increment_requests(service_config.id)

    assert {:ok, plan} = Router.route(request_ctx, service_config)
    assert plan.selected_model.id == service_config.backup_model.id
    assert plan.reason == :backup_due_to_load
  end

  test "rejects when hard limit exceeded" do
    service_config = build_service_config(3, routing_hard_limit: 1, routing_soft_limit: 1)
    request_ctx = %{request_type: :generate}

    AdmissionControl.increment_requests(service_config.id)

    assert {:error, :over_capacity} = Router.route(request_ctx, service_config)
  end

  test "routes to backup when primary breaker is open" do
    service_config = build_service_config(4)
    request_ctx = %{request_type: :generate}

    AdmissionControl.put_breaker_snapshot(service_config.primary_model.id, %{state: :open})

    assert {:ok, plan} = Router.route(request_ctx, service_config)
    assert plan.selected_model.id == service_config.backup_model.id
    assert plan.reason == :primary_breaker_open
  end

  test "rejects when both breakers are open" do
    service_config = build_service_config(5)
    request_ctx = %{request_type: :generate}

    AdmissionControl.put_breaker_snapshot(service_config.primary_model.id, %{state: :open})
    AdmissionControl.put_breaker_snapshot(service_config.backup_model.id, %{state: :open})

    assert {:error, :all_breakers_open} = Router.route(request_ctx, service_config)
  end

  defp build_service_config(id, overrides \\ %{}) do
    primary = %RegisteredModel{id: id * 10 + 1, name: "Primary", provider: :null}
    backup = %RegisteredModel{id: id * 10 + 2, name: "Backup", provider: :null}

    base = %ServiceConfig{
      id: id,
      name: "ServiceConfig #{id}",
      primary_model: primary,
      backup_model: backup,
      routing_soft_limit: 2,
      routing_hard_limit: 3,
      routing_stream_soft_limit: 1,
      routing_stream_hard_limit: 2,
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
