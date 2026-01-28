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
    counts = AdmissionControl.counts(service_config.id)
    {soft_limit, hard_limit} = limits(service_config)
    soft_limit_reached? = is_integer(soft_limit) and counts.requests >= soft_limit
    hard_limit_reached? = is_integer(hard_limit) and counts.requests >= hard_limit

    primary = service_config.primary_model

    secondary =
      normalize_secondary(service_config.secondary_model, primary, service_config.backup_model)

    backup = service_config.backup_model

    primary_snapshot = breaker_snapshot(primary)
    secondary_snapshot = if secondary, do: breaker_snapshot(secondary), else: %{state: :closed}
    backup_snapshot = if backup, do: breaker_snapshot(backup), else: %{state: :closed}

    primary_open = breaker_open?(primary_snapshot)
    secondary_open = secondary && breaker_open?(secondary_snapshot)
    backup_open = backup && breaker_open?(backup_snapshot)

    result =
      cond do
        hard_limit_reached? ->
          {:error, :over_capacity}

        (soft_limit_reached? and not primary_open and secondary) && not secondary_open ->
          attempt_secondary(
            service_config,
            secondary,
            secondary_open,
            counts,
            request_type,
            :service_config_soft_limit
          )

        primary_open and (is_nil(secondary) or secondary_open) ->
          attempt_backup(service_config, backup, backup_open, counts, request_type, :backup_outage)

        primary_open ->
          attempt_secondary(
            service_config,
            secondary,
            secondary_open,
            counts,
            request_type,
            :primary_breaker_open
          )

        true ->
          case attempt_primary(service_config, primary, counts, request_type) do
            {:ok, _plan} = ok ->
              ok

            {:error, :over_capacity} ->
              case secondary do
                nil ->
                  attempt_backup(
                    service_config,
                    backup,
                    backup_open,
                    counts,
                    request_type,
                    :primary_over_capacity
                  )

                _ ->
                  attempt_secondary(
                    service_config,
                    secondary,
                    secondary_open,
                    counts,
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
      service_config,
      counts,
      soft_limit,
      hard_limit
    )

    log_decision(result, request_type, service_config, counts, soft_limit, hard_limit)

    result
  end

  defp breaker_snapshot(%{id: id}) do
    Breaker.snapshot(id)
  end

  defp breaker_open?(snapshot) do
    snapshot.state == :open
  end

  defp limits(service_config) do
    {service_config.routing_soft_limit, service_config.routing_hard_limit}
  end

  defp build_plan(service_config, request_type, counts, selected, tier, pool_name, reason) do
    %RoutingPlan{
      selected_model: selected,
      tier: tier,
      fallback_models: [],
      reason: reason,
      admission: :admit,
      timeouts: %{
        request_timeout_ms: service_config.routing_timeout_ms,
        connect_timeout_ms: service_config.routing_connect_timeout_ms
      },
      counts: counts,
      request_type: request_type,
      pool_name: pool_name
    }
  end

  defp attempt_primary(service_config, primary, counts, request_type) do
    attempt_candidate(service_config, primary, counts, request_type, :primary, :primary_normal)
  end

  defp attempt_secondary(_service_config, nil, _secondary_open, _counts, _request_type, _reason) do
    {:error, :secondary_unavailable}
  end

  defp attempt_secondary(_service_config, _secondary, true, _counts, _request_type, _reason) do
    {:error, :secondary_breaker_open}
  end

  defp attempt_secondary(service_config, secondary, false, counts, request_type, reason) do
    case attempt_candidate(service_config, secondary, counts, request_type, :secondary, reason) do
      {:ok, _plan} = ok -> ok
      {:error, :over_capacity} -> {:error, :secondary_over_capacity}
      {:error, reason} -> {:error, reason}
    end
  end

  defp attempt_backup(_service_config, nil, _backup_open, _counts, _request_type, _reason) do
    {:error, :all_breakers_open}
  end

  defp attempt_backup(_service_config, _backup, true, _counts, _request_type, _reason) do
    {:error, :backup_breaker_open}
  end

  defp attempt_backup(service_config, backup, false, counts, request_type, reason) do
    attempt_candidate(service_config, backup, counts, request_type, :backup, reason)
  end

  defp attempt_candidate(service_config, model, counts, request_type, tier, reason) do
    pool_name = HackneyPool.pool_name(model)
    pool_limit = HackneyPool.max_connections(model.pool_class || :slow)

    case AdmissionControl.try_admit_pool(pool_name, pool_limit) do
      :ok ->
        case admit_model(model) do
          :ok ->
            {:ok,
             build_plan(service_config, request_type, counts, model, tier, pool_name, reason)}

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

  defp emit_telemetry(
         result,
         duration_ms,
         request_type,
         service_config,
         counts,
         soft_limit,
         hard_limit
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
        soft_limit: soft_limit,
        hard_limit: hard_limit,
        counts: counts,
        tier: tier,
        pool_name: pool_name,
        pool_class: pool_class
      }
    )
  end

  defp log_decision(result, request_type, service_config, counts, soft_limit, hard_limit) do
    case result do
      {:ok, plan} ->
        Logger.debug("GenAI routing plan",
          service_config_id: service_config.id,
          selected_model_id: plan.selected_model.id,
          tier: plan.tier,
          pool_name: plan.pool_name,
          reason: plan.reason,
          request_type: request_type,
          counts: counts
        )

      {:error, reason} ->
        Logger.warning("GenAI routing rejected",
          service_config_id: service_config.id,
          reason: reason,
          request_type: request_type,
          counts: counts,
          soft_limit: soft_limit,
          hard_limit: hard_limit
        )
    end
  end
end
