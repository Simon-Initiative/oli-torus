# Acceptance coverage: AC-019, AC-020, AC-021.
defmodule Oli.GenAI.OperationsTest do
  use Oli.DataCase, async: false
  alias Oli.GenAI
  alias Oli.GenAI.{Diagnostics, Operations}
  alias Oli.GenAI.Completions.RegisteredModel

  test "audit is secret-free and rollback prepares rotated Provider credentials (AC-020, AC-021)" do
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

    assert Enum.any?(
             audit.model_issues,
             &(&1.model_id == m.id and &1.category == :legacy_connection_differs)
           )

    assert Enum.any?(
             audit.allocations_per_node,
             &(&1.service_config_id == config.id and &1.capacity == 7)
           )

    refute inspect(audit) =~ "rotated-secret"

    # Seeded models may have an initially missing key; make rollback valid for all OpenAI Providers.
    for provider <- GenAI.providers(),
        provider.adapter == :open_ai,
        do:
          GenAI.update_provider(provider, %{
            api_key: provider.api_key || "seed-key",
            base_url: provider.base_url || "https://example.test"
          })

    assert {:ok, count} = Operations.prepare_legacy_rollback()
    assert count > 0
    assert Repo.get!(RegisteredModel, m.id).api_key == "rotated-secret"
  end

  test "rollback preparation rejects missing, incompatible and invalid connections atomically (AC-020, AC-021)" do
    for provider <- GenAI.providers(),
        provider.adapter == :open_ai,
        do:
          GenAI.update_provider(provider, %{
            api_key: provider.api_key || "seed-key",
            base_url: provider.base_url || "https://example.test"
          })

    {:ok, first} =
      GenAI.create_provider(%{
        name: "Rollback first",
        adapter: :open_ai,
        base_url: "https://first.test",
        api_key: "original"
      })

    {:ok, m1} =
      GenAI.create_registered_model(%{name: "First", model: "first", provider_id: first.id})

    {:ok, _} = GenAI.update_provider(first, %{api_key: "rotated"})

    {:ok, second} =
      GenAI.create_provider(%{
        name: "Rollback second",
        adapter: :open_ai,
        base_url: "https://second.test",
        api_key: "second"
      })

    {:ok, m2} =
      GenAI.create_registered_model(%{name: "Second", model: "second", provider_id: second.id})

    {:ok, second} = GenAI.update_provider(second, %{enabled: false})

    for invalid <- [:missing_provider, :incompatible, :invalid_endpoint] do
      Repo.get!(RegisteredModel, m2.id)
      |> Ecto.Changeset.change(provider_id: second.id)
      |> Repo.update!()

      case invalid do
        :missing_provider ->
          Repo.update!(Ecto.Changeset.change(m2, provider_id: nil))

        :incompatible ->
          GenAI.update_provider(second, %{adapter: :null})

        :invalid_endpoint ->
          GenAI.update_provider(second, %{adapter: :open_ai, base_url: "invalid"})
      end

      assert {:error, :invalid_legacy_connection} = Operations.prepare_legacy_rollback()
      assert Repo.get!(RegisteredModel, m1.id).api_key == "original"
    end
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
