defmodule Oli.GenAI.Router do
  @moduledoc "Best-effort tier selection using actual transport occupancy and independent Provider health."
  alias Oli.GenAI.{PoolManager, RoutingPlan, Runtime, Telemetry, TransportPool}
  alias Oli.GenAI.Completions.ServiceConfig

  @doc "Observes occupancy without reserving capacity; subsequent checkout may briefly queue."
  def route(ctx, %ServiceConfig{} = supplied) do
    started = System.monotonic_time(:millisecond)

    result =
      with {:ok, inputs} <- inputs(ctx, supplied.id),
           :ok <- main_configuration(inputs) do
        provider = inputs.providers[inputs.config.primary_model.provider_id]

        case provider do
          %{enabled: false} ->
            backup_candidate(ctx, inputs, provider.id)

          %{adapter: :null} ->
            {:ok,
             %Oli.GenAI.RoutingPlan{
               selected_model: inputs.config.primary_model,
               provider: provider,
               tier: :primary,
               service_config_id: supplied.id,
               request_type: Map.get(ctx, :request_type, :generate),
               reason: :local_adapter
             }}

          %{adapter: :open_ai} ->
            case eligibility(inputs, provider.id) do
              :ok -> main(ctx, inputs)
              :unavailable -> backup_candidate(ctx, inputs, provider.id)
              :ineligible -> {:error, :provider_ineligible}
            end

          _ ->
            {:error, :unsupported_adapter}
        end
      end

    emit(result, supplied.id, ctx, started)
    result
  end

  @doc "Selects a distinct eligible backup for one pre-output availability failure."
  def backup(ctx, config, excluded_provider_id) do
    started = System.monotonic_time(:millisecond)

    result =
      with {:ok, inputs} <- inputs(ctx, config.id),
           do: backup_candidate(ctx, inputs, excluded_provider_id)

    emit(result, config.id, ctx, started)
    result
  end

  defp inputs(ctx, id) do
    Runtime.routing_configuration(id, Map.get(ctx, :runtime, Runtime))
  catch
    :exit, _ -> {:error, :configuration_unavailable}
  end

  defp main_configuration(%{config: config, providers: providers}) do
    p = config.primary_model
    s = config.secondary_model

    cond do
      not is_struct(p, Oli.GenAI.Completions.RegisteredModel) or
          not Map.has_key?(providers, p.provider_id) ->
        {:error, :invalid_configuration}

      is_struct(s, Ecto.Association.NotLoaded) ->
        {:error, :invalid_configuration}

      s != nil and (s.id == p.id or s.provider_id != p.provider_id) ->
        {:error, :invalid_configuration}

      true ->
        :ok
    end
  end

  defp eligibility(inputs, id) do
    case inputs.health[id] do
      %{eligible: true} -> :ok
      %{administrative_enabled: false} -> :unavailable
      %{observed: :unavailable} -> :unavailable
      _ -> :ineligible
    end
  end

  defp main(ctx, inputs) do
    case candidate(ctx, inputs, :primary, :primary_normal) do
      {:error, :busy} -> candidate(ctx, inputs, :secondary, :primary_full)
      result -> result
    end
  end

  defp backup_candidate(ctx, inputs, excluded) do
    case inputs.config.backup_model do
      %{provider_id: id} when not is_nil(id) and id != excluded ->
        case eligibility(inputs, id) do
          :ok -> candidate(ctx, inputs, :backup, :provider_unavailable)
          _ -> {:error, :backup_unavailable}
        end

      _ ->
        {:error, :backup_unavailable}
    end
  end

  defp candidate(ctx, inputs, tier, reason) do
    model = Map.fetch!(inputs.config, field(tier))
    key = {inputs.config.id, tier}

    with %Oli.GenAI.Completions.RegisteredModel{} <- model,
         %{adapter: :open_ai, api_key: key_value} = provider
         when is_binary(key_value) and byte_size(key_value) > 0 <-
           inputs.providers[model.provider_id],
         {:ok, pool} <- PoolManager.lookup(inputs.pool_manager, key),
         %{current: %{checked_out: occupied, capacity: capacity, name: name, queue_depth: queue}}
         when is_integer(occupied) and is_integer(capacity) <- TransportPool.snapshot(pool) do
      :telemetry.execute(
        [:oli, :genai, :pool, :occupancy],
        %{checked_out: occupied, capacity: capacity, queue_depth: queue},
        %{service_config_id: inputs.config.id, tier: tier}
      )

      case occupied < capacity do
        true ->
          {:ok,
           %RoutingPlan{
             selected_model: model,
             provider: provider,
             pool: pool,
             pool_name: name,
             service_config_id: inputs.config.id,
             tier: tier,
             reason: reason,
             signature: Oli.GenAI.Provider.transport_signature(provider, model),
             request_type: Map.get(ctx, :request_type, :generate)
           }}

        false ->
          {:error, :busy}
      end
    else
      nil -> {:error, :busy}
      _ -> {:error, :pool_unavailable}
    end
  catch
    :exit, _ -> {:error, :pool_unavailable}
  end

  defp field(:primary), do: :primary_model
  defp field(:secondary), do: :secondary_model
  defp field(:backup), do: :backup_model

  defp emit(result, id, ctx, started) do
    metadata =
      case result do
        {:ok, plan} ->
          %{reason: plan.reason, selected_model_id: plan.selected_model.id, tier: plan.tier}

        {:error, reason} ->
          %{reason: reason}
      end

    Telemetry.router_decision(
      %{count: 1, duration_ms: System.monotonic_time(:millisecond) - started},
      Map.merge(
        metadata,
        %{service_config_id: id, request_type: Map.get(ctx, :request_type, :generate)}
      )
    )
  end
end
