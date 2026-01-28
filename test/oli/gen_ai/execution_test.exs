defmodule Oli.GenAI.ExecutionTest do
  use ExUnit.Case, async: false

  alias Oli.GenAI.{AdmissionControl, BreakerSupervisor, Execution, HackneyPool}
  alias Oli.GenAI.Completions.{RegisteredModel, ServiceConfig}

  setup do
    ensure_started(AdmissionControl)
    ensure_registry_started()
    ensure_started(BreakerSupervisor)
    clear_tables()
    :ok
  end

  test "returns error when primary fails and no fallback is attempted" do
    Process.put(:execution_test_pid, self())

    service_config = build_service_config(1)
    primary_id = service_config.primary_model.id
    backup_id = service_config.backup_model.id
    request_ctx = %{request_type: :generate}

    assert {:error, {:http_error, 500}} =
             Execution.generate(
               request_ctx,
               [],
               [],
               service_config,
               completions_mod: __MODULE__.FakeCompletions
             )

    assert_received {:generate_called, ^primary_id}
    refute_received {:generate_called, ^backup_id}
  end

  test "rejects when secondary is over capacity" do
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

    assert {:error, :secondary_over_capacity} =
             Execution.generate(
               request_ctx,
               [],
               [],
               service_config,
               completions_mod: __MODULE__.FakeCompletions
             )
  end

  test "routes to secondary when primary breaker is open" do
    Process.put(:execution_test_pid, self())

    service_config = build_service_config(3)
    request_ctx = %{request_type: :generate}

    AdmissionControl.put_breaker_snapshot(service_config.primary_model.id, %{state: :open})

    assert {:ok, _} =
             Execution.generate(
               request_ctx,
               [],
               [],
               service_config,
               completions_mod: __MODULE__.AlwaysOkCompletions
             )

    secondary_id = service_config.secondary_model.id
    assert_received {:generate_called, ^secondary_id}
  end

  test "routes to backup when primary and secondary breakers are open" do
    Process.put(:execution_test_pid, self())

    service_config = build_service_config(4)
    request_ctx = %{request_type: :generate}

    AdmissionControl.put_breaker_snapshot(service_config.primary_model.id, %{state: :open})
    AdmissionControl.put_breaker_snapshot(service_config.secondary_model.id, %{state: :open})

    assert {:ok, _} =
             Execution.generate(
               request_ctx,
               [],
               [],
               service_config,
               completions_mod: __MODULE__.AlwaysOkCompletions
             )

    backup_id = service_config.backup_model.id
    assert_received {:generate_called, ^backup_id}
  end

  test "releases pool admission after execution completes" do
    ensure_hackney_started()
    HackneyPool.set_max_connections(:slow, 1)

    service_config = build_service_config(5, secondary_model: nil)
    request_ctx = %{request_type: :generate}
    Process.put(:execution_test_pid, self())

    assert {:ok, _} =
             Execution.generate(
               request_ctx,
               [],
               [],
               service_config,
               completions_mod: __MODULE__.AlwaysOkCompletions
             )

    assert {:ok, _} =
             Execution.generate(
               request_ctx,
               [],
               [],
               service_config,
               completions_mod: __MODULE__.AlwaysOkCompletions
             )
  end

  test "opens breaker on OpenAI 429 status_code errors" do
    model_id = 51
    Process.put(:execution_test_pid, self())

    service_config =
      build_service_config(6,
        primary_model: %RegisteredModel{
          id: model_id,
          name: "Primary",
          provider: :null,
          max_concurrent: nil,
          routing_breaker_429_threshold: 0.2,
          routing_breaker_error_rate_threshold: 1.0,
          routing_breaker_latency_p95_ms: 10_000,
          routing_open_cooldown_ms: 0,
          routing_half_open_probe_count: 1
        },
        secondary_model: nil,
        backup_model: nil
      )

    request_ctx = %{request_type: :generate}

    Enum.each(1..5, fn _ ->
      assert {:error, _} =
               Execution.generate(
                 request_ctx,
                 [],
                 [],
                 service_config,
                 completions_mod: __MODULE__.OpenAI429Completions
               )

      Process.sleep(5)
    end)

    assert eventually(fn ->
             snapshot = AdmissionControl.get_breaker_snapshot(model_id)
             snapshot.state == :open
           end)
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

  defmodule AlwaysOkCompletions do
    def generate(_messages, _functions, %RegisteredModel{id: id}) do
      send(Process.get(:execution_test_pid), {:generate_called, id})
      {:ok, %{response: "ok"}}
    end

    def stream(_messages, _functions, _registered_model, _response_handler_fn) do
      :ok
    end
  end

  defmodule OpenAI429Completions do
    def generate(_messages, _functions, %RegisteredModel{id: id}) do
      send(Process.get(:execution_test_pid), {:generate_called, id})
      {:error, %{status_code: 429}}
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
end
