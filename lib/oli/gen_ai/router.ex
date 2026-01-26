defmodule Oli.GenAI.Router do
  @moduledoc """
  Computes a RoutingPlan for GenAI requests based on ServiceConfig policy,
  live counters, and breaker state.
  """

  require Logger

  alias Oli.GenAI.AdmissionControl
  alias Oli.GenAI.Breaker
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
    {soft_limit, hard_limit} = limits(service_config, request_type)

    current = current_count(counts, request_type)

    result =
      if current >= hard_limit do
        {:error, :over_capacity}
      else
        primary = service_config.primary_model
        backup = service_config.backup_model

        primary_snapshot = breaker_snapshot(primary)
        backup_snapshot = if backup, do: breaker_snapshot(backup), else: %{state: :closed}

        cond do
          breaker_open?(primary_snapshot) and backup && breaker_available?(backup_snapshot) ->
            {:ok,
             build_plan(
               service_config,
               request_type,
               counts,
               backup,
               [primary],
               :primary_breaker_open
             )}

          breaker_open?(primary_snapshot) and
              (is_nil(backup) or not breaker_available?(backup_snapshot)) ->
            {:error, :all_breakers_open}

          current >= soft_limit and backup && breaker_available?(backup_snapshot) ->
            {:ok,
             build_plan(
               service_config,
               request_type,
               counts,
               backup,
               [primary],
               :backup_due_to_load
             )}

          true ->
            {:ok,
             build_plan(
               service_config,
               request_type,
               counts,
               primary,
               Enum.reject([backup], &is_nil/1),
               primary_reason(primary_snapshot)
             )}
        end
      end

    duration_ms = System.monotonic_time(:millisecond) - start_ms

    emit_telemetry(result, duration_ms, request_type, service_config, counts, soft_limit, hard_limit)
    log_decision(result, request_type, service_config, counts, soft_limit, hard_limit)

    result
  end

  defp breaker_snapshot(%{id: id}) do
    Breaker.snapshot(id)
  end

  defp breaker_open?(snapshot) do
    snapshot.state == :open
  end

  defp breaker_available?(snapshot) do
    case snapshot.state do
      :open -> false
      :half_open -> (snapshot[:half_open_remaining] || 0) > 0
      _ -> true
    end
  end

  defp primary_reason(snapshot) do
    case snapshot.state do
      :half_open -> :primary_half_open
      _ -> :primary_normal
    end
  end

  defp limits(service_config, request_type) do
    case request_type do
      :stream -> {service_config.routing_stream_soft_limit, service_config.routing_stream_hard_limit}
      _ -> {service_config.routing_soft_limit, service_config.routing_hard_limit}
    end
  end

  defp current_count(counts, request_type) do
    case request_type do
      :stream -> counts.streams
      _ -> counts.requests
    end
  end

  defp build_plan(service_config, request_type, counts, selected, fallback_models, reason) do
    %RoutingPlan{
      selected_model: selected,
      fallback_models: fallback_models,
      reason: reason,
      admission: :admit,
      timeouts: %{
        request_timeout_ms: service_config.routing_timeout_ms,
        connect_timeout_ms: service_config.routing_connect_timeout_ms
      },
      counts: counts,
      request_type: request_type
    }
  end

  defp emit_telemetry(result, duration_ms, request_type, service_config, counts, soft_limit, hard_limit) do
    {reason, selected_model_id, admitted} =
      case result do
        {:ok, plan} -> {plan.reason, plan.selected_model.id, 1}
        {:error, reason} -> {reason, nil, 0}
      end

    Telemetry.router_decision(
      %{duration_ms: duration_ms},
      %{
        service_config_id: service_config.id,
        selected_model_id: selected_model_id,
        reason: reason,
        request_type: request_type
      }
    )

    Telemetry.router_admission(
      %{admitted: admitted},
      %{
        service_config_id: service_config.id,
        request_type: request_type,
        soft_limit: soft_limit,
        hard_limit: hard_limit,
        counts: counts
      }
    )
  end

  defp log_decision(result, request_type, service_config, counts, soft_limit, hard_limit) do
    case result do
      {:ok, plan} ->
        Logger.debug("GenAI routing plan",
          service_config_id: service_config.id,
          selected_model_id: plan.selected_model.id,
          fallback_model_ids: Enum.map(plan.fallback_models, & &1.id),
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
