# Acceptance coverage: AC-001, AC-002, AC-003.
defmodule Oli.GenAI.ProviderConfigurationTest do
  use Oli.DataCase, async: false
  alias Oli.GenAI
  alias Oli.GenAI.Configuration
  alias Oli.GenAI.Completions.{RegisteredModel, ServiceConfig}

  test "Provider secrets are encrypted and excluded from inspection" do
    provider = provider()
    assert provider.api_key == "provider-secret"
    refute inspect(provider) =~ "provider-secret"

    %{rows: [[ciphertext]]} =
      Repo.query!("SELECT api_key FROM gen_ai_providers WHERE id = $1", [provider.id])

    refute ciphertext == "provider-secret"

    assert {:error, changeset} =
             GenAI.create_provider(%{
               name: "bad",
               adapter: :open_ai,
               api_key: "secret",
               base_url: "http://user:password@example.com"
             })

    assert errors_on(changeset).base_url != []
  end

  test "designation is persisted, deterministic, non-unique and reconciled after clearing or deletion" do
    provider = provider()
    first = model(provider)
    second = model(provider)
    assert first.health_check
    refute second.health_check
    assert {:ok, second} = GenAI.update_registered_model(second, %{health_check: true})
    assert {:ok, selected} = GenAI.reconcile_probe_model(provider.id)
    assert selected.id == first.id
    assert {:ok, _} = GenAI.update_registered_model(first, %{health_check: false})
    assert {:ok, selected} = GenAI.reconcile_probe_model(provider.id)
    assert selected.id == second.id
    assert {:ok, _} = GenAI.update_registered_model(second, %{health_check: false})
    assert {:ok, selected} = GenAI.reconcile_probe_model(provider.id)
    assert selected.id == first.id
    assert {:ok, _} = GenAI.delete_registered_model(selected)
    assert {:ok, selected} = GenAI.reconcile_probe_model(provider.id)
    assert selected.id == second.id
    assert Repo.get!(RegisteredModel, second.id).health_check
  end

  test "membership edits reconcile both Providers and stale forms do not restore old membership" do
    source = provider()
    destination = provider()
    moving = model(source)
    replacement = model(source)
    assert {:ok, moved} = GenAI.update_registered_model(moving, %{provider_id: destination.id})
    assert {:ok, selected} = GenAI.reconcile_probe_model(source.id)
    assert selected.id == replacement.id
    assert {:ok, renamed} = GenAI.update_registered_model(moving, %{name: "renamed stale form"})
    assert renamed.provider_id == moved.provider_id
    assert {:ok, selected} = GenAI.reconcile_probe_model(destination.id)
    assert selected.id == moving.id
  end

  test "a Provider without models reports no model and cannot be deleted while referenced" do
    provider = provider()
    assert {:ok, nil} = GenAI.reconcile_probe_model(provider.id)
    model(provider)
    assert {:error, _changeset} = GenAI.delete_provider(provider)
  end

  test "ServiceConfig validates Provider and capability boundaries" do
    main = provider()
    other = provider()
    primary = model(main, %{capabilities: ["tools"]})
    secondary = model(main, %{capabilities: ["tools"]})
    backup = model(other, %{capabilities: ["tools"]})

    attrs = %{
      name: "valid",
      primary_model_id: primary.id,
      secondary_model_id: secondary.id,
      backup_model_id: backup.id,
      required_capabilities: ["tools"],
      primary_pool_capacity: 7
    }

    assert {:ok, config} = GenAI.create_service_config(attrs)
    assert config.primary_pool_capacity == 7

    assert {:error, invalid} =
             GenAI.create_service_config(%{
               attrs
               | secondary_model_id: backup.id,
                 backup_model_id: nil
             })

    assert errors_on(invalid).secondary_model_id != []

    assert {:error, invalid} =
             GenAI.create_service_config(%{
               attrs
               | backup_model_id: secondary.id,
                 secondary_model_id: nil
             })

    assert errors_on(invalid).backup_model_id != []

    assert {:error, invalid} =
             GenAI.create_service_config(%{attrs | required_capabilities: ["vision"]})

    assert errors_on(invalid).primary_model_id != []
    assert {:error, invalid} = GenAI.create_service_config(%{attrs | primary_pool_capacity: 0})
    assert errors_on(invalid).primary_pool_capacity != []
  end

  test "model reassignment cannot invalidate an existing ServiceConfig" do
    main = provider()
    other = provider()
    primary = model(main)
    secondary = model(main)

    assert {:ok, _} =
             GenAI.create_service_config(%{
               name: "linked",
               primary_model_id: primary.id,
               secondary_model_id: secondary.id
             })

    assert {:error, _} = GenAI.update_registered_model(secondary, %{provider_id: other.id})
    assert Repo.get!(RegisteredModel, secondary.id).provider_id == main.id
  end

  test "committed changes broadcast invalidation and rejected changes do not" do
    Phoenix.PubSub.subscribe(Oli.PubSub, Configuration.topic())
    provider = provider()
    assert_receive :genai_configuration_changed
    assert {:error, _} = GenAI.update_provider(provider, %{base_url: "invalid"})
    refute_receive :genai_configuration_changed
    assert {:ok, updated} = GenAI.update_provider(provider, %{api_key: "rotated-secret"})
    assert updated.config_version == provider.config_version + 1
    assert_receive :genai_configuration_changed
    refute inspect(updated) =~ "rotated-secret"
  end

  test "configuration reload reports additive model fields and existing post-migration audit issues" do
    provider = provider()
    primary = model(provider)
    backup = model(provider)

    legacy =
      Repo.insert!(%ServiceConfig{
        name: "legacy same-Provider backup",
        primary_model_id: primary.id,
        backup_model_id: backup.id
      })

    assert %{valid?: false} = Configuration.audit_service_config(legacy)
    config = Configuration.runtime_configuration()

    assert Enum.any?(
             config.providers,
             &(&1.provider.id == provider.id and &1.model.id == primary.id)
           )

    assert Enum.any?(config.service_configs, &(&1.id == legacy.id))
  end

  test "disabled-check reload does not mutate probe flags merely because the override is active" do
    provider = provider()
    model = model(provider)

    Repo.update_all(from(m in RegisteredModel, where: m.id == ^model.id),
      set: [health_check: false]
    )

    loaded = Configuration.runtime_configuration(reconcile_probes: false)
    assert Enum.find(loaded.providers, &(&1.provider.id == provider.id)).model == nil
    refute Repo.get!(RegisteredModel, model.id).health_check
    loaded = Configuration.runtime_configuration(reconcile_probes: true)
    assert Enum.find(loaded.providers, &(&1.provider.id == provider.id)).model.id == model.id
    assert Repo.get!(RegisteredModel, model.id).health_check
  end

  test "nil capacities and capability arrays return changeset errors rather than database exceptions" do
    provider = provider()
    primary = model(provider)
    attrs = %{name: "invalid-null", primary_model_id: primary.id}

    for value <- [nil, ""] do
      assert {:error, invalid} =
               GenAI.create_service_config(Map.put(attrs, :primary_pool_capacity, value))

      assert errors_on(invalid).primary_pool_capacity != []
    end

    assert {:error, invalid} =
             GenAI.create_service_config(Map.put(attrs, :required_capabilities, nil))

    assert errors_on(invalid).required_capabilities != []
    assert {:error, invalid} = GenAI.update_registered_model(primary, %{capabilities: nil})
    assert errors_on(invalid).capabilities != []
    assert {:ok, _} = GenAI.create_service_config(Map.put(attrs, :required_capabilities, []))
    assert {:ok, _} = GenAI.update_registered_model(primary, %{capabilities: []})
  end

  test "an existing missing-key or malformed Provider can be disabled but must be repaired before enabling" do
    incomplete =
      Repo.insert!(%Oli.GenAI.Provider{
        name: "Incomplete legacy connection",
        adapter: :open_ai,
        base_url: "malformed-endpoint",
        api_key: nil
      })

    assert {:ok, disabled} = GenAI.update_provider(incomplete, %{enabled: false})
    refute disabled.enabled
    assert {:error, invalid} = GenAI.update_provider(disabled, %{enabled: true})
    assert errors_on(invalid).api_key != []
    assert errors_on(invalid).base_url != []

    assert {:ok, repaired} =
             GenAI.update_provider(disabled, %{
               enabled: true,
               base_url: "http://127.0.0.1:9999",
               api_key: "repaired-key"
             })

    assert repaired.enabled
  end

  test "periodic configuration reads are batched independently of Provider count" do
    small = runtime_select_count()

    for _ <- 1..8 do
      p = provider()
      model(p)
    end

    assert runtime_select_count() == small
    assert small == 4
  end

  @doc false
  def record_query(_event, _measurements, metadata, pid) do
    case String.starts_with?(metadata.query, "SELECT") do
      true -> send(pid, :runtime_select)
      false -> :ok
    end
  end

  defp runtime_select_count do
    id = {__MODULE__, make_ref()}
    :ok = :telemetry.attach(id, [:oli, :repo, :query], &__MODULE__.record_query/4, self())

    try do
      Configuration.runtime_configuration()
    after
      :telemetry.detach(id)
    end

    count_selects(0)
  end

  defp count_selects(count) do
    receive do
      :runtime_select -> count_selects(count + 1)
    after
      0 -> count
    end
  end

  test "Provider-backed model creation keeps credentials exclusively on Provider" do
    provider = provider()

    assert {:ok, registered} =
             GenAI.create_registered_model(%{
               name: "Provider-owned model",
               model: "test-model",
               provider_id: provider.id
             })

    assert registered.provider_id == provider.id
    refute Map.has_key?(registered, :api_key)
    refute Map.has_key?(registered, :secondary_api_key)
    refute Map.has_key?(registered, :provider)
    refute Map.has_key?(registered, :url_template)
    assert registered.health_check
  end

  test "model creation requires an explicit Provider even when Providers exist" do
    provider()

    assert {:error, changeset} =
             GenAI.create_registered_model(%{name: "Missing Provider", model: "test"})

    assert "can't be blank" in errors_on(changeset).provider_id
  end

  test "nested rolled-back configuration writes do not publish uncommitted changes" do
    Phoenix.PubSub.subscribe(Oli.PubSub, Configuration.topic())

    assert {:error, :cancelled} =
             Repo.transaction(fn ->
               provider()
               Repo.rollback(:cancelled)
             end)

    refute_receive :genai_configuration_changed
  end

  defp provider do
    {:ok, provider} =
      GenAI.create_provider(%{
        name: "Test connection",
        adapter: :open_ai,
        base_url: "http://127.0.0.1:9999",
        api_key: "provider-secret"
      })

    provider
  end

  defp model(provider, overrides \\ %{}) do
    {:ok, model} =
      GenAI.create_registered_model(
        Map.merge(
          %{
            name: "model",
            provider_id: provider.id,
            model: "test-model"
          },
          overrides
        )
      )

    model
  end
end
