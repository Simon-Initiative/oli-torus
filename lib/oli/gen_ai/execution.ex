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
        release_admission!(plan)
      end
    end
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
      plan,
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
      plan,
      service_config,
      response_handler_fn,
      request_type
    )
  end

  defp execute_generate(
         completer,
         messages,
         functions,
         plan,
         service_config,
         request_type
       ) do
    start_ms = System.monotonic_time(:millisecond)
    result = completer.generate(messages, functions, plan.selected_model)
    latency_ms = System.monotonic_time(:millisecond) - start_ms

    report_breaker(result, plan.selected_model, latency_ms)
    emit_provider_telemetry(result, latency_ms, plan, request_type, service_config)
    result
  end

  defp execute_stream(
         completer,
         messages,
         functions,
         plan,
         service_config,
         response_handler_fn,
         request_type
       ) do
    start_ms = System.monotonic_time(:millisecond)
    error_key = {:genai_stream_error, make_ref()}
    Process.put(error_key, false)

    wrapped_handler = fn chunk ->
      if chunk == :error or match?({:error, _}, chunk) or chunk == {:error} do
        Process.put(error_key, true)
      end

      response_handler_fn.(chunk)
    end

    result = completer.stream(messages, functions, plan.selected_model, wrapped_handler)
    latency_ms = System.monotonic_time(:millisecond) - start_ms

    error_seen? = Process.get(error_key, false)
    Process.delete(error_key)

    result =
      if error_seen? do
        {:error, :stream_error}
      else
        result
      end

    report_breaker(result, plan.selected_model, latency_ms)
    emit_provider_telemetry(result, latency_ms, plan, request_type, service_config)
    result
  end

  defp report_breaker(result, registered_model, latency_ms) do
    {outcome, http_status, _error_category} = outcome_details(result)

    Breaker.report(registered_model.id, %{
      outcome: outcome,
      http_status: http_status,
      latency_ms: latency_ms,
      thresholds: breaker_thresholds(registered_model)
    })
  end

  defp outcome_details({:ok, _}), do: {:ok, nil, nil}

  defp outcome_details({:error, reason}) do
    {http_status, error_category} = error_details(reason)

    {:error, http_status, error_category}
  end

  defp outcome_details(:ok), do: {:ok, nil, nil}
  defp outcome_details(_), do: {:error, nil, :unknown}

  defp error_details(:timeout), do: {nil, :timeout}
  defp error_details(:stream_error), do: {nil, :stream_error}
  defp error_details(:connect_timeout), do: {nil, :timeout}
  defp error_details(:recv_timeout), do: {nil, :timeout}
  defp error_details({:timeout, _}), do: {nil, :timeout}

  defp error_details(%{status: status}) when is_integer(status) do
    {status, http_status_category(status)}
  end

  defp error_details(%{http_status: status}) when is_integer(status) do
    {status, http_status_category(status)}
  end

  defp error_details(%{status_code: status}) when is_integer(status) do
    {status, http_status_category(status)}
  end

  defp error_details({:http_error, status}) when is_integer(status) do
    {status, http_status_category(status)}
  end

  defp error_details(_), do: {nil, :unknown}

  defp http_status_category(429), do: :rate_limited
  defp http_status_category(_status), do: :http_error

  defp breaker_thresholds(registered_model) do
    %{
      error_rate_threshold: registered_model.routing_breaker_error_rate_threshold || 0.2,
      rate_limit_threshold: registered_model.routing_breaker_429_threshold || 0.1,
      latency_p95_ms: registered_model.routing_breaker_latency_p95_ms || 6000,
      open_cooldown_ms: registered_model.routing_open_cooldown_ms || 30_000,
      half_open_probe_count: registered_model.routing_half_open_probe_count || 3
    }
  end

  defp release_admission!(%{pool_name: pool_name, selected_model: %{id: model_id}}) do
    AdmissionControl.release_pool(pool_name)
    AdmissionControl.release_model(model_id)
  end

  defp release_admission!(_), do: :ok

  defp emit_provider_telemetry(result, latency_ms, plan, request_type, service_config) do
    {outcome, http_status, error_category} = outcome_details(result)

    Telemetry.provider_stop(
      %{duration_ms: latency_ms},
      %{
        service_config_id: service_config.id,
        registered_model_id: plan.selected_model.id,
        provider: plan.selected_model.provider,
        model: plan.selected_model.model,
        tier: plan.tier,
        pool_name: plan.pool_name,
        pool_class: plan.selected_model.pool_class || :slow,
        reason: plan.reason,
        outcome: outcome,
        http_status: http_status,
        error_category: error_category,
        request_type: request_type
      }
    )
  end
end
