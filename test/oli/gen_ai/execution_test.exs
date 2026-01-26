defmodule Oli.GenAI.ExecutionTest do
  use ExUnit.Case, async: false

  alias Oli.GenAI.{AdmissionControl, BreakerSupervisor, Execution}
  alias Oli.GenAI.Completions.{RegisteredModel, ServiceConfig}

  setup do
    ensure_started(AdmissionControl)
    ensure_registry_started()
    ensure_started(BreakerSupervisor)
    clear_tables()
    :ok
  end

  test "falls back to backup model when primary fails" do
    Process.put(:execution_test_pid, self())

    service_config = build_service_config(1)
    primary_id = service_config.primary_model.id
    backup_id = service_config.backup_model.id
    request_ctx = %{request_type: :generate}

    assert {:ok, _} =
             Execution.generate(
               request_ctx,
               [],
               [],
               service_config,
               completions_mod: __MODULE__.FakeCompletions
             )

    assert_received {:generate_called, ^primary_id}
    assert_received {:generate_called, ^backup_id}
  end

  test "rejects when router returns over_capacity" do
    service_config = build_service_config(2, routing_hard_limit: 1, routing_soft_limit: 1)
    request_ctx = %{request_type: :generate}

    AdmissionControl.increment_requests(service_config.id)

    assert {:error, :over_capacity} =
             Execution.generate(
               request_ctx,
               [],
               [],
               service_config,
               completions_mod: __MODULE__.FakeCompletions
             )
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
      routing_breaker_error_rate_threshold: 0.2,
      routing_breaker_429_threshold: 0.1,
      routing_breaker_latency_p95_ms: 6000,
      routing_open_cooldown_ms: 10,
      routing_half_open_probe_count: 1,
      routing_timeout_ms: 30_000,
      routing_connect_timeout_ms: 5_000
    }

    struct(base, overrides)
  end

  defmodule FakeCompletions do
    def generate(_messages, _functions, %RegisteredModel{id: id}) do
      send(Process.get(:execution_test_pid), {:generate_called, id})

      if id |> rem(2) == 1 do
        {:error, {:http_error, 500}}
      else
        {:ok, %{response: "ok"}}
      end
    end

    def stream(_messages, _functions, _registered_model, _response_handler_fn) do
      :ok
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
