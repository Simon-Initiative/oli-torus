defmodule Oli.GenAI.Router do
  @moduledoc """
  Computes a RoutingPlan for GenAI requests based on ServiceConfig policy,
  live counters, and breaker state.
  """

  require Logger

  alias Oli.GenAI.AdmissionControl
  alias Oli.GenAI.Breaker
  alias Oli.GenAI.HackneyPool
  alias Oli.GenAI.RoutingPlan
  alias Oli.GenAI.Telemetry
  alias Oli.GenAI.Completions.ServiceConfig

  @doc """
  Returns a RoutingPlan or a rejection reason for a request.

  The decision uses ETS counters and breaker snapshots and is intended to be fast.
  """
  def route(request_ctx, %ServiceConfig{} = service_config) do
    start_ms = System.monotonic_time(:millisecond)
    request_type = Map.get(request_ctx, :request_type, :generate)

    primary = normalize_model(service_config.primary_model)

    secondary =
      normalize_secondary(service_config.secondary_model, primary, service_config.backup_model)

    backup = normalize_model(service_config.backup_model)

    primary_snapshot = breaker_snapshot(primary)
    secondary_snapshot = if secondary, do: breaker_snapshot(secondary), else: %{state: :closed}
    backup_snapshot = if backup, do: breaker_snapshot(backup), else: %{state: :closed}

    primary_open = primary && breaker_open?(primary_snapshot)
    secondary_open = secondary && breaker_open?(secondary_snapshot)
    backup_open = backup && breaker_open?(backup_snapshot)

    result =
      cond do
        (primary && primary_open) and (is_nil(secondary) or secondary_open) ->
          attempt_backup(
            backup,
            backup_open,
            request_type,
            :backup_outage
          )

        primary && primary_open ->
          attempt_secondary(
            secondary,
            secondary_open,
            request_type,
            :primary_breaker_open
          )

        true ->
          case attempt_primary(primary, request_type) do
            {:ok, _plan} = ok ->
              ok

            {:error, :over_capacity} ->
              case secondary do
                nil ->
                  attempt_backup(
                    backup,
                    backup_open,
                    request_type,
                    :primary_over_capacity
                  )

                _ ->
                  attempt_secondary(
                    secondary,
                    secondary_open,
                    request_type,
                    :primary_over_capacity
                  )
              end

            {:error, reason} ->
              {:error, reason}
          end
      end

    duration_ms = System.monotonic_time(:millisecond) - start_ms

    emit_telemetry(
      result,
      duration_ms,
      request_type,
      service_config
    )

    log_decision(result, request_type, service_config)

    result
  end

  defp breaker_snapshot(%{id: id}), do: Breaker.snapshot(id)
  defp breaker_snapshot(nil), do: %{state: :closed}

  defp breaker_open?(snapshot) do
    snapshot.state == :open
  end

  defp build_plan(request_type, selected, tier, pool_name, reason) do
    %RoutingPlan{
      selected_model: selected,
      tier: tier,
      fallback_models: [],
      reason: reason,
      admission: :admit,
      request_type: request_type,
      pool_name: pool_name
    }
  end

  defp attempt_primary(primary, request_type) do
    if primary do
      attempt_candidate(primary, request_type, :primary, :primary_normal)
    else
      {:error, :primary_unavailable}
    end
  end

  defp attempt_secondary(nil, _secondary_open, _request_type, _reason) do
    {:error, :secondary_unavailable}
  end

  defp attempt_secondary(_secondary, true, _request_type, _reason) do
    {:error, :secondary_breaker_open}
  end

  defp attempt_secondary(secondary, false, request_type, reason) do
    case attempt_candidate(secondary, request_type, :secondary, reason) do
      {:ok, _plan} = ok -> ok
      {:error, :over_capacity} -> {:error, :secondary_over_capacity}
      {:error, reason} -> {:error, reason}
    end
  end

  defp attempt_backup(nil, _backup_open, _request_type, _reason) do
    {:error, :all_breakers_open}
  end

  defp attempt_backup(_backup, true, _request_type, _reason) do
    {:error, :backup_breaker_open}
  end

  defp attempt_backup(backup, false, request_type, reason) do
    attempt_candidate(backup, request_type, :backup, reason)
  end

  defp attempt_candidate(model, request_type, tier, reason) do
    pool_name = HackneyPool.pool_name(model)
    pool_limit = HackneyPool.max_connections(model.pool_class || :slow)

    case AdmissionControl.try_admit_pool(pool_name, pool_limit) do
      :ok ->
        case admit_model(model) do
          :ok ->
            {:ok, build_plan(request_type, model, tier, pool_name, reason)}

          {:error, :over_capacity} ->
            AdmissionControl.release_pool(pool_name)
            {:error, :over_capacity}

          {:error, reason} ->
            AdmissionControl.release_pool(pool_name)
            {:error, reason}
        end

      {:error, :over_capacity} ->
        {:error, :over_capacity}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp admit_model(%{id: model_id, max_concurrent: nil}) do
    AdmissionControl.increment_model(model_id)
    :ok
  end

  defp admit_model(%{id: model_id, max_concurrent: max_concurrent})
       when is_integer(max_concurrent) and max_concurrent >= 0 do
    AdmissionControl.try_admit_model(model_id, max_concurrent)
  end

  defp admit_model(_), do: {:error, :invalid_limit}

  defp normalize_secondary(nil, _primary, _backup), do: nil

  defp normalize_secondary(%Ecto.Association.NotLoaded{}, _primary, _backup), do: nil

  defp normalize_secondary(secondary, primary, backup) do
    cond do
      secondary.id == primary.id -> nil
      not is_nil(backup) and secondary.id == backup.id -> nil
      true -> secondary
    end
  end

  defp normalize_model(%Ecto.Association.NotLoaded{}), do: nil
  defp normalize_model(model), do: model

  defp emit_telemetry(
         result,
         duration_ms,
         request_type,
         service_config
       ) do
    {reason, selected_model_id, tier, pool_name, pool_class, admitted} =
      case result do
        {:ok, plan} ->
          model_pool_class = plan.selected_model.pool_class || :slow
          {plan.reason, plan.selected_model.id, plan.tier, plan.pool_name, model_pool_class, 1}

        {:error, reason} ->
          {reason, nil, nil, nil, nil, 0}
      end

    Telemetry.router_decision(
      %{duration_ms: duration_ms},
      %{
        service_config_id: service_config.id,
        selected_model_id: selected_model_id,
        reason: reason,
        request_type: request_type,
        tier: tier,
        pool_name: pool_name,
        pool_class: pool_class
      }
    )

    Telemetry.router_admission(
      %{admitted: admitted},
      %{
        service_config_id: service_config.id,
        request_type: request_type,
        tier: tier,
        pool_name: pool_name,
        pool_class: pool_class
      }
    )
  end

  defp log_decision(result, request_type, service_config) do
    case result do
      {:ok, plan} ->
        Logger.debug("GenAI routing plan",
          service_config_id: service_config.id,
          selected_model_id: plan.selected_model.id,
          tier: plan.tier,
          pool_name: plan.pool_name,
          reason: plan.reason,
          request_type: request_type
        )

      {:error, reason} ->
        Logger.warning("GenAI routing rejected",
          service_config_id: service_config.id,
          reason: reason,
          request_type: request_type
        )
    end
  end
end
