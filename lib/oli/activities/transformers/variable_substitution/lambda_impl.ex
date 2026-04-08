defmodule Oli.Activities.Transformers.VariableSubstitution.LambdaImpl do
  alias Oli.Activities.Transformers.VariableSubstitution.Strategy
  alias Oli.Activities.Transformers.VariableSubstitution.Common

  import Oli.HTTP, only: [aws: 0]
  require Logger

  @behaviour Strategy
  @payload_error "Error retrieving the payload"
  @invoke_event [:oli, :eval_engine, :lambda, :invoke]
  @decode_event [:oli, :eval_engine, :lambda, :decode]

  @impl Strategy
  def substitute(model, evaluation_digest) do
    Common.replace_variables(model, evaluation_digest)
  end

  @impl Strategy
  def provide_batch_context(transformers) do
    config = Application.fetch_env!(:oli, :variable_substitution)
    request_meta = request_meta(config, transformers)

    payload = %{
      vars:
        Enum.map(transformers, fn transformer ->
          Enum.map(transformer.data, fn data -> data end)
        end),
      count: 1
    }

    config
    |> invoke_lambda(payload, request_meta)
    |> normalize_lambda_response(request_meta)
  end

  defp invoke_lambda(config, payload, request_meta) do
    started_at = System.monotonic_time()

    response =
      config[:aws_fn_name]
      |> ExAws.Lambda.invoke(payload, "no_context")
      |> aws().request(region: config[:aws_region])

    duration_ms = duration_ms(started_at)

    metadata =
      request_meta
      |> Map.merge(%{
        outcome: invoke_outcome(response),
        error_category: invoke_error_category(response)
      })

    :telemetry.execute(@invoke_event, %{duration_ms: duration_ms}, metadata)
    log_invocation(duration_ms, metadata)

    response
  end

  defp normalize_lambda_response({:ok, response}, request_meta) do
    started_at = System.monotonic_time()

    result =
      case decode_response(response) do
        {:ok, decoded} -> validate_decoded_response(decoded)
        {:error, _reason} = error -> error
      end

    duration_ms = duration_ms(started_at)

    metadata =
      request_meta
      |> Map.merge(%{
        outcome: decode_outcome(result),
        error_category: decode_error_category(result),
        response_descriptor: response_descriptor(response)
      })

    :telemetry.execute(@decode_event, %{duration_ms: duration_ms}, metadata)
    log_decode(duration_ms, metadata)

    result
  end

  defp normalize_lambda_response({:error, reason}, _request_meta), do: {:error, reason}

  defp decode_response(response) when is_binary(response) do
    Jason.decode(response)
  end

  defp decode_response(%{body: body}) when is_binary(body) do
    Jason.decode(body)
  end

  defp decode_response(%{"body" => body}) when is_binary(body) do
    Jason.decode(body)
  end

  defp decode_response(response), do: {:ok, response}

  defp validate_decoded_response(response) when is_list(response) do
    case Enum.all?(response, &is_list/1) do
      true -> {:ok, response}
      false -> {:error, @payload_error}
    end
  end

  defp validate_decoded_response(%{"error" => _error}), do: {:error, @payload_error}
  defp validate_decoded_response(%{error: _error}), do: {:error, @payload_error}
  defp validate_decoded_response(_response), do: {:error, @payload_error}

  defp request_meta(config, transformers) do
    %{
      function_name: config[:aws_fn_name],
      region: config[:aws_region],
      request_batch_count: Enum.count(transformers),
      request_variable_count:
        Enum.reduce(transformers, 0, fn transformer, total ->
          total + Enum.count(transformer.data)
        end)
    }
  end

  defp duration_ms(started_at) do
    (System.monotonic_time() - started_at)
    |> System.convert_time_unit(:native, :millisecond)
  end

  defp invoke_outcome({:ok, _response}), do: :ok
  defp invoke_outcome({:error, _reason}), do: :error

  defp invoke_error_category({:ok, _response}), do: nil
  defp invoke_error_category({:error, reason}), do: categorize_reason(reason)

  defp decode_outcome({:ok, _response}), do: :ok
  defp decode_outcome({:error, _reason}), do: :error

  defp decode_error_category({:ok, _response}), do: nil
  defp decode_error_category({:error, %Jason.DecodeError{}}), do: :json_decode_error
  defp decode_error_category({:error, @payload_error}), do: :invalid_payload
  defp decode_error_category({:error, reason}), do: categorize_reason(reason)

  defp response_descriptor(response) when is_binary(response), do: :binary
  defp response_descriptor(%{body: body}) when is_binary(body), do: :body
  defp response_descriptor(%{"body" => body}) when is_binary(body), do: :string_key_body
  defp response_descriptor(response) when is_list(response), do: :decoded_list
  defp response_descriptor(response) when is_map(response), do: :decoded_map
  defp response_descriptor(_response), do: :decoded_term

  defp categorize_reason(reason) when is_atom(reason), do: reason
  defp categorize_reason(%{__struct__: module}), do: module
  defp categorize_reason({category, _detail}) when is_atom(category), do: category
  defp categorize_reason(_reason), do: :unknown

  defp log_invocation(duration_ms, metadata) do
    log_metadata = Keyword.put(Map.to_list(metadata), :duration_ms, duration_ms)

    case metadata.outcome do
      :ok ->
        Logger.info("Variable substitution Lambda invocation completed", log_metadata)

      :error ->
        Logger.warning("Variable substitution Lambda invocation failed", log_metadata)
    end
  end

  defp log_decode(duration_ms, metadata) do
    log_metadata = Keyword.put(Map.to_list(metadata), :duration_ms, duration_ms)

    case metadata.outcome do
      :ok ->
        Logger.info("Variable substitution Lambda response decoded", log_metadata)

      :error ->
        Logger.warning("Variable substitution Lambda response decode failed", log_metadata)
    end
  end
end
