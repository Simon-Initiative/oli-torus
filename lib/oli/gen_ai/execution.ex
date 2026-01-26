defmodule Oli.GenAI.Execution do
  @moduledoc """
  Executes GenAI requests using routing plans, counters, and breakers.

  This module wraps provider calls, applies fallback rules, and emits telemetry.
  """

  require Logger

  alias Oli.GenAI.AdmissionControl
  alias Oli.GenAI.Breaker
  alias Oli.GenAI.Router
  alias Oli.GenAI.Telemetry
  alias Oli.GenAI.Completions
  alias Oli.GenAI.Completions.ServiceConfig

  @doc """
  Executes a synchronous completion request with routing and fallback.
  """
  def generate(request_ctx, messages, functions, %ServiceConfig{} = service_config, opts \\ []) do
    with {:ok, plan} <- Router.route(request_ctx, service_config) do
      completer = Keyword.get(opts, :completions_mod, Completions)
      request_type = Map.get(request_ctx, :request_type, :generate)

      admit!(service_config.id, request_type)

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
        release!(service_config.id, request_type)
      end
    end
  end

  @doc """
  Executes a streaming completion request with routing and fallback.
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

      admit!(service_config.id, request_type)

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
        release!(service_config.id, request_type)
      end
    end
  end

  defp admit!(service_config_id, request_type) do
    AdmissionControl.increment_requests(service_config_id)

    if request_type == :stream do
      AdmissionControl.increment_streams(service_config_id)
    end
  end

  defp release!(service_config_id, request_type) do
    AdmissionControl.decrement_requests(service_config_id)

    if request_type == :stream do
      AdmissionControl.decrement_streams(service_config_id)
    end
  end

  defp execute_with_fallback(
         :generate,
         completer,
         messages,
         functions,
         plan,
         service_config,
         request_ctx,
         request_type
       ) do
    result =
      execute_generate(
        completer,
        messages,
        functions,
        plan.selected_model,
        service_config,
        request_type
      )

    case result do
      {:ok, _} ->
        result

      {:error, _} = error ->
        attempt_fallback_generate(
          completer,
          messages,
          functions,
          plan,
          service_config,
          request_ctx,
          request_type,
          error
        )
    end
  end

  defp execute_with_fallback(
         :stream,
         completer,
         messages,
         functions,
         plan,
         service_config,
         request_ctx,
         request_type,
         response_handler_fn
       ) do
    result =
      execute_stream(
        completer,
        messages,
        functions,
        plan.selected_model,
        service_config,
        response_handler_fn,
        request_type
      )

    case result do
      :ok ->
        :ok

      {:error, _} = error ->
        attempt_fallback_stream(
          completer,
          messages,
          functions,
          plan,
          service_config,
          request_ctx,
          request_type,
          error,
          response_handler_fn
        )
    end
  end

  defp attempt_fallback_generate(
         _completer,
         _messages,
         _functions,
         %{fallback_models: []},
         _service_config,
         _request_ctx,
         _request_type,
         error
       ),
       do: error

  defp attempt_fallback_generate(
         completer,
         messages,
         functions,
         plan,
         service_config,
         _request_ctx,
         request_type,
         _error
       ) do
    case List.first(plan.fallback_models) do
      nil ->
        {:error, :fallback_unavailable}

      fallback_model ->
        Logger.info("Falling back to backup model #{fallback_model.id} for GenAI generate")
        execute_generate(
          completer,
          messages,
          functions,
          fallback_model,
          service_config,
          request_type
        )
    end
  end

  defp attempt_fallback_stream(
         _completer,
         _messages,
         _functions,
         %{fallback_models: []},
         _service_config,
         _request_ctx,
         _request_type,
         error,
         _response_handler_fn
       ),
       do: error

  defp attempt_fallback_stream(
         completer,
         messages,
         functions,
         plan,
         service_config,
         _request_ctx,
         request_type,
         _error,
         response_handler_fn
       ) do
    case List.first(plan.fallback_models) do
      nil ->
        {:error, :fallback_unavailable}

      fallback_model ->
        Logger.info("Falling back to backup model #{fallback_model.id} for GenAI stream")

        execute_stream(
          completer,
          messages,
          functions,
          fallback_model,
          service_config,
          response_handler_fn,
          request_type
        )
    end
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

    report_breaker(result, registered_model.id, latency_ms, service_config)
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

    report_breaker(result, registered_model.id, latency_ms, service_config)
    emit_provider_telemetry(result, latency_ms, registered_model, request_type, service_config)
    result
  end

  defp report_breaker(result, registered_model_id, latency_ms, service_config) do
    {outcome, http_status} = outcome_details(result)

    Breaker.report(registered_model_id, %{
      outcome: outcome,
      http_status: http_status,
      latency_ms: latency_ms,
      thresholds: %{
        error_rate_threshold: service_config.routing_breaker_error_rate_threshold,
        rate_limit_threshold: service_config.routing_breaker_429_threshold,
        latency_p95_ms: service_config.routing_breaker_latency_p95_ms,
        open_cooldown_ms: service_config.routing_open_cooldown_ms,
        half_open_probe_count: service_config.routing_half_open_probe_count
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
