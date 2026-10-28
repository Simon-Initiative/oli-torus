# Acceptance coverage: AC-019, AC-020, AC-021.
defmodule Oli.GenAI.OperationsTest do
  use Oli.DataCase, async: false
  alias Oli.GenAI
  alias Oli.GenAI.{Diagnostics, Operations}

  test "audit is secret-free after Provider credential rotation (AC-020, AC-021)" do
    {:ok, p} =
      GenAI.create_provider(%{
        name: "Audit",
        adapter: :open_ai,
        base_url: "https://example.test",
        api_key: "original-secret"
      })

    {:ok, m} =
      GenAI.create_registered_model(%{name: "Audit model", model: "a", provider_id: p.id})

    {:ok, config} =
      GenAI.create_service_config(%{
        name: "Audit config",
        primary_model_id: m.id,
        primary_pool_capacity: 7
      })

    {:ok, _} = GenAI.update_provider(p, %{api_key: "rotated-secret"})
    audit = Operations.audit()

    refute Enum.any?(audit.model_issues, &(&1.model_id == m.id))

    assert Enum.any?(
             audit.allocations_per_node,
             &(&1.service_config_id == config.id and &1.capacity == 7)
           )

    refute inspect(audit) =~ "rotated-secret"
  end

  test "the release retires legacy accounting supervision and metric wiring (AC-021)" do
    children = Supervisor.which_children(Oli.Supervisor)

    refute Enum.any?(children, fn {id, _, _, _} ->
             id in [
               Oli.GenAI.AdmissionControl,
               Oli.GenAI.BreakerSupervisor,
               Oli.GenAI.BreakerRegistry
             ]
           end)

    for event <- [[:oli, :genai, :router, :admission], [:oli, :genai, :breaker, :state_change]] do
      refute Enum.any?(:telemetry.list_handlers(event), &(&1.id == "genai-appsignal-handler"))
    end

    assert Enum.any?(
             :telemetry.list_handlers([:oli, :genai, :health, :probe]),
             &(&1.id == "genai-appsignal-handler")
           )
  end

  test "diagnostics distinguish safe operational states without inspecting raw failures (AC-018, AC-019)" do
    assert Diagnostics.status(nil) =~ "Unknown"
    assert Diagnostics.status(%{administrative_enabled: false}) =~ "Administratively disabled"
    assert Diagnostics.status(%{monitoring_enabled: false}) =~ "Health checks disabled"
    assert Diagnostics.status(%{failure_category: :missing_probe_model}) =~ "missing_probe_model"
    assert Diagnostics.status(%{observed: :stale}) == "Stale"
    assert Diagnostics.test_result({:error, %{body: "sensitive"}}) == "Test failed: request_error"
  end
end
