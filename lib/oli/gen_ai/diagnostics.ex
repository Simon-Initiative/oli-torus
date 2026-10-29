defmodule Oli.GenAI.Diagnostics do
  @moduledoc "Safe node-local administrative diagnostics with no credentials or raw transport errors."
  alias Oli.GenAI.{PoolManager, Runtime}

  @doc "Returns operational state; absent infrastructure is explicitly unknown rather than healthy."
  def snapshot(runtime \\ Runtime, manager \\ PoolManager) do
    health =
      safe(fn -> Runtime.snapshot(runtime) end, %{providers: %{}, error: :runtime_unavailable})

    defaults = %{
      administrative_enabled: nil,
      monitoring_enabled: nil,
      observed: :unknown,
      health_check_model_id: nil,
      last_check: nil,
      last_success: nil,
      next_check: nil,
      consecutive_failures: 0,
      consecutive_successes: 0,
      failure_category: :monitor_unavailable
    }

    health = %{
      health
      | providers:
          Map.new(health.providers, fn {id, state} -> {id, Map.merge(defaults, state)} end)
    }

    %{
      node: node(),
      primary_only: Oli.GenAI.PrimaryOnly.enabled?(),
      health: health,
      pools: safe(fn -> PoolManager.snapshot(manager) end, %{pools: %{}, retired: %{}})
    }
  end

  @doc "Builds display rows for configured ServiceConfig tiers from a single diagnostic snapshot."
  def tiers(config, snapshot) do
    for tier <- [:primary, :secondary, :backup],
        model = Map.get(config, String.to_existing_atom("#{tier}_model")),
        is_struct(model, Oli.GenAI.Completions.RegisteredModel) do
      provider = snapshot.health.providers[model.provider_id]
      pool = snapshot.pools.pools[{config.id, tier}]

      %{
        tier: tier,
        model: model.name,
        provider_id: model.provider_id,
        status: status(provider),
        occupancy: pool && pool.current,
        retiring:
          case pool do
            nil -> 0
            p -> length(p.retired)
          end,
        transport:
          case Map.get(provider || %{}, :adapter) do
            :open_ai -> "HTTP/1.1"
            :null -> "Local"
            _ -> "Unsupported adapter"
          end
      }
    end
  end

  @doc "Distinguishes disabled checks, administrative disablement, missing configuration and observed health."
  def status(nil), do: "Unknown (runtime unavailable)"
  def status(%{administrative_enabled: false}), do: "Administratively disabled"
  def status(%{monitoring_enabled: false}), do: "Health checks disabled"

  def status(%{failure_category: category})
      when category in [
             :missing_probe_model,
             :invalid_probe_model,
             :incompatible_probe_model,
             :missing_credentials,
             :invalid_endpoint,
             :unsupported_probe_adapter
           ],
      do: "Configuration: #{category}"

  def status(%{observed: observed}), do: String.capitalize(to_string(observed))

  @doc "Returns a bounded user-facing category; never inspects raw provider payloads."
  def test_result({:ok, _}), do: "Test successful"

  def test_result({:error, reason})
      when reason in [
             :busy,
             :provider_ineligible,
             :configuration_unavailable,
             :pool_unavailable,
             :inference_deadline,
             :unsupported_administrative_transport
           ],
      do: "Test failed: #{reason}"

  def test_result(_), do: "Test failed: request_error"

  defp safe(fun, fallback) do
    fun.()
  catch
    :exit, _ -> fallback
  end
end
