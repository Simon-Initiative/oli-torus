defmodule Oli.GenAI.Execution do
  @moduledoc """
  Executes GenAI requests using routing plans, counters, and breakers.

  This module wraps provider calls, applies routing decisions, and emits telemetry.
  """

  alias Oli.GenAI.AdmissionControl
  alias Oli.GenAI.Breaker
  alias Oli.GenAI.Router
  alias Oli.GenAI.Telemetry
  alias Oli.GenAI.Completions
  alias Oli.GenAI.Completions.ServiceConfig

  @doc """
  Executes a synchronous completion request with routing.
  """
  def generate(request_ctx, messages, functions, %ServiceConfig{} = service_config, opts \\ []) do
    with {:ok, plan} <- Router.route(request_ctx, service_config) do
      completer = Keyword.get(opts, :completions_mod, Completions)
      request_type = Map.get(request_ctx, :request_type, :generate)

      admit!(service_config.id)

      try do
        execute_with_fallback(
          :generate,
          completer,
          messages,
          functions,
          plan,
          service_config,
          request_ctx,
          request_type
        )
      after
        release!(service_config.id)
        release_admission!(plan)
      end
    end
  end

  @doc """
  Executes a streaming completion request with routing.
  """
  def stream(
        request_ctx,
        messages,
        functions,
        %ServiceConfig{} = service_config,
        response_handler_fn,
        opts \\ []
      ) do
    with {:ok, plan} <- Router.route(request_ctx, service_config) do
      completer = Keyword.get(opts, :completions_mod, Completions)
      request_type = Map.get(request_ctx, :request_type, :stream)

      admit!(service_config.id)

      try do
        execute_with_fallback(
          :stream,
          completer,
          messages,
          functions,
          plan,
          service_config,
          request_ctx,
          request_type,
          response_handler_fn
        )
      after
        release!(service_config.id)
        release_admission!(plan)
      end
    end
  end

  defp admit!(service_config_id) do
    AdmissionControl.increment_requests(service_config_id)
  end

  defp release!(service_config_id) do
    AdmissionControl.decrement_requests(service_config_id)
  end

  defp execute_with_fallback(
         :generate,
         completer,
         messages,
         functions,
         plan,
         service_config,
         _request_ctx,
         request_type
       ) do
    execute_generate(
      completer,
      messages,
      functions,
      plan.selected_model,
      service_config,
      request_type
    )
  end

  defp execute_with_fallback(
         :stream,
         completer,
         messages,
         functions,
         plan,
         service_config,
         _request_ctx,
         request_type,
         response_handler_fn
       ) do
    execute_stream(
      completer,
      messages,
      functions,
      plan.selected_model,
      service_config,
      response_handler_fn,
      request_type
    )
  end

  defp execute_generate(
         completer,
         messages,
         functions,
         registered_model,
         service_config,
         request_type
       ) do
    start_ms = System.monotonic_time(:millisecond)
    result = completer.generate(messages, functions, registered_model)
    latency_ms = System.monotonic_time(:millisecond) - start_ms

    report_breaker(result, registered_model, latency_ms)
    emit_provider_telemetry(result, latency_ms, registered_model, request_type, service_config)
    result
  end

  defp execute_stream(
         completer,
         messages,
         functions,
         registered_model,
         service_config,
         response_handler_fn,
         request_type
       ) do
    start_ms = System.monotonic_time(:millisecond)
    error_key = {:genai_stream_error, make_ref()}
    Process.put(error_key, false)

    wrapped_handler = fn chunk ->
      if chunk == {:error} do
        Process.put(error_key, true)
      end

      response_handler_fn.(chunk)
    end

    result = completer.stream(messages, functions, registered_model, wrapped_handler)
    latency_ms = System.monotonic_time(:millisecond) - start_ms

    error_seen? = Process.get(error_key, false)
    Process.delete(error_key)

    result =
      if error_seen? do
        {:error, :stream_error}
      else
        result
      end

    report_breaker(result, registered_model, latency_ms)
    emit_provider_telemetry(result, latency_ms, registered_model, request_type, service_config)
    result
  end

  defp report_breaker(result, registered_model, latency_ms) do
    {outcome, http_status} = outcome_details(result)

    Breaker.report(registered_model.id, %{
      outcome: outcome,
      http_status: http_status,
      latency_ms: latency_ms,
      thresholds: %{
        error_rate_threshold: registered_model.routing_breaker_error_rate_threshold,
        rate_limit_threshold: registered_model.routing_breaker_429_threshold,
        latency_p95_ms: registered_model.routing_breaker_latency_p95_ms,
        open_cooldown_ms: registered_model.routing_open_cooldown_ms,
        half_open_probe_count: registered_model.routing_half_open_probe_count
      }
    })
  end

  defp outcome_details({:ok, _}), do: {:ok, nil}

  defp outcome_details({:error, reason}) do
    http_status =
      case reason do
        %{status: status} when is_integer(status) -> status
        %{http_status: status} when is_integer(status) -> status
        {:http_error, status} when is_integer(status) -> status
        _ -> nil
      end

    {:error, http_status}
  end

  defp outcome_details(:ok), do: {:ok, nil}
  defp outcome_details(_), do: {:error, nil}

  defp release_admission!(%{pool_name: pool_name, selected_model: %{id: model_id}}) do
    AdmissionControl.release_pool(pool_name)
    AdmissionControl.release_model(model_id)
  end

  defp release_admission!(_), do: :ok

  defp emit_provider_telemetry(result, latency_ms, registered_model, request_type, service_config) do
    {outcome, http_status} = outcome_details(result)

    Telemetry.provider_stop(
      %{duration_ms: latency_ms},
      %{
        service_config_id: service_config.id,
        registered_model_id: registered_model.id,
        provider: registered_model.provider,
        model: registered_model.model,
        outcome: outcome,
        http_status: http_status,
        request_type: request_type
      }
    )
  end
end
