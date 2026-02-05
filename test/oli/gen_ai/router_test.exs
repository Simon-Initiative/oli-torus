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

  test "rejects when secondary is over capacity and primary is at cap" do
    service_config =
      build_service_config(7,
        primary_model: %RegisteredModel{
          id: 71,
          name: "Primary",
          provider: :null,
          max_concurrent: 0
        },
        secondary_model: %RegisteredModel{
          id: 72,
          name: "Secondary",
          provider: :null,
          max_concurrent: 0
        }
      )

    request_ctx = %{request_type: :generate}

    assert {:error, :secondary_over_capacity} = Router.route(request_ctx, service_config)
  end

  test "routes to backup when primary over capacity and no secondary configured" do
    service_config =
      build_service_config(9,
        primary_model: %RegisteredModel{
          id: 91,
          name: "Primary",
          provider: :null,
          max_concurrent: 0
        },
        secondary_model: nil
      )

    request_ctx = %{request_type: :generate}

    assert {:ok, plan} = Router.route(request_ctx, service_config)
    assert plan.selected_model.id == service_config.backup_model.id
    assert plan.tier == :backup
    assert plan.reason == :primary_over_capacity
  end

  test "rejects when pool is at max connections" do
    ensure_hackney_started()
    Oli.GenAI.HackneyPool.set_max_connections(:slow, 1)

    service_config = build_service_config(10, secondary_model: nil)
    request_ctx = %{request_type: :generate}

    assert {:ok, _plan} = Router.route(request_ctx, service_config)
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
      backup_model: backup
    }

    struct(base, overrides)
  end

  defp ensure_started(mod) do
    case Process.whereis(mod) do
      nil -> start_supervised!(mod)
      _pid -> :ok
    end
  end

  defp ensure_hackney_started do
    case Process.whereis(Oli.GenAI.HackneyPool) do
      nil -> start_supervised!(Oli.GenAI.HackneyPool)
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
