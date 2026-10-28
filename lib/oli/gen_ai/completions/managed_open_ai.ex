defmodule Oli.GenAI.Completions.ManagedOpenAI do
  @moduledoc "OpenAI HTTP/1.1 execution through the exact selected transport coordinator."
  alias Oli.GenAI.{Provider, TransportPool}
  alias Oli.GenAI.Completions.OpenAICompliantProvider, as: OpenAI

  @doc "Runs one attempt; the caller owns its connection until completion or process death."
  def request(mode, messages, functions, plan, handler, opts) do
    model = plan.selected_model
    provider = plan.provider
    url = String.trim_trailing(Provider.endpoint(provider, model), "/") <> "/v1/chat/completions"

    body =
      OpenAI.completion_params(
        model.model,
        messages,
        functions,
        Keyword.put(opts, :stream, mode == :stream)
      )
      |> Map.new()
      |> Jason.encode!()

    # Do not inherit global SDK credentials or automatic retries.
    headers = [
      {"Authorization", "Bearer " <> provider.api_key},
      {"Content-Type", "application/json"}
    ]

    headers =
      case provider.organization_key do
        nil -> headers
        key -> [{"OpenAI-Organization", key} | headers]
      end

    with {:ok, ref} <-
           TransportPool.connect(plan.pool, url,
             expected_signature: plan.signature,
             deadline: Keyword.fetch!(opts, :deadline),
             connect_timeout: model.timeout || 8_000,
             checkout_timeout: 1_000,
             recv_timeout: model.recv_timeout || 60_000
           ) do
      try do
        uri = URI.parse(url)

        target =
          (uri.path || "/") <>
            case uri.query do
              nil -> ""
              query -> "?" <> query
            end

        case :hackney.send_request(ref, {:post, target, headers, body}) do
          {:ok, 200, _, response} -> consume(mode, response, handler)
          {:ok, status, _, _} -> {:error, %{http_status: status, error_category: :http_error}}
          {:error, reason} -> transport_error(reason)
        end
      after
        case :hackney.close(ref) do
          :ok ->
            :ok

          _ ->
            :telemetry.execute([:oli, :genai, :pool, :cleanup_error], %{count: 1}, %{
              service_config_id: plan.service_config_id,
              tier: plan.tier
            })
        end
      end
    else
      {:error, reason}
      when reason in [
             :busy,
             :pool_unavailable,
             :stale_configuration,
             :invalid_origin,
             :invalid_options
           ] ->
        {:error, reason}

      {:error, reason} ->
        transport_error(reason)
    end
  end

  defp consume(:generate, ref, _) do
    case :hackney.body(ref, 8_388_609) do
      {:ok, body} when byte_size(body) <= 8_388_608 ->
        case Jason.decode(body) do
          {:ok, %{"choices" => [%{"message" => %{"content" => content}} | _]}}
          when is_binary(content) ->
            {:ok, content}

          _ ->
            {:error, :invalid_response}
        end

      {:ok, _} ->
        {:error, :response_too_large}

      {:error, reason} ->
        transport_error(reason)
    end
  end

  defp consume(:stream, ref, handler), do: read_stream(ref, handler, "", false)

  defp read_stream(ref, handler, buffer, finished) do
    case :hackney.stream_body(ref) do
      {:ok, chunk} ->
        data = String.replace(buffer <> chunk, "\r\n", "\n")
        parts = String.split(data, "\n\n")
        {complete, [rest]} = Enum.split(parts, -1)

        case byte_size(rest) > 1_048_576 or Enum.any?(complete, &(byte_size(&1) > 1_048_576)) do
          true ->
            {:error, :response_too_large}

          false ->
            with {:ok, finished} <- events(complete, handler, finished) do
              case finished do
                true -> :ok
                false -> read_stream(ref, handler, rest, false)
              end
            end
        end

      :done ->
        case finished and String.trim(buffer) == "" do
          true -> :ok
          false -> {:error, :truncated_stream}
        end

      {:error, reason} ->
        transport_error(reason)
    end
  end

  defp events([], _, finished), do: {:ok, finished}

  defp events([event | rest], handler, finished) do
    payload =
      event
      |> String.split("\n")
      |> Enum.flat_map(fn
        "data:" <> line -> [String.trim_leading(line)]
        _ -> []
      end)
      |> Enum.join("\n")

    case payload do
      "" ->
        events(rest, handler, finished)

      "[DONE]" ->
        # A terminal completion is required; an isolated DONE marker is a truncated response.
        case finished do
          true -> events(rest, handler, true)
          false -> {:error, :truncated_stream}
        end

      _ ->
        with {:ok, decoded} <- Jason.decode(payload),
             :ok <- valid_event(decoded),
             {:ok, terminal} <- deliver(decoded, handler) do
          events(rest, handler, finished or terminal)
        else
          _ -> {:error, :invalid_response}
        end
    end
  end

  defp valid_event(%{"error" => _}), do: {:error, :upstream_error}
  defp valid_event(%{"choices" => []}), do: :ok

  defp valid_event(%{"choices" => [choice | _]}) when is_map(choice) do
    delta = Map.get(choice, "delta", %{})

    case is_map(delta) and (is_nil(delta["content"]) or is_binary(delta["content"])) do
      true -> :ok
      false -> {:error, :invalid_response}
    end
  end

  defp valid_event(_), do: {:error, :invalid_response}

  defp deliver(%{"choices" => []}, _), do: {:ok, false}

  defp deliver(%{"choices" => [choice | _]} = decoded, handler) do
    reason = choice["finish_reason"]
    terminal = reason in ["stop", "length", "tool_calls", "content_filter"]
    delta = Map.get(choice, "delta", %{})

    delta =
      case Map.get(delta, "content") do
        nil -> Map.delete(delta, "content")
        _ -> delta
      end

    # Some compatible APIs put final content and a finish reason in the same event.
    choice =
      choice |> Map.put("finish_reason", nil) |> Map.put("delta", Map.delete(delta, "role"))

    case OpenAI.process_stream_chunk(Map.put(decoded, "choices", [choice])) do
      {:error} ->
        {:error, :invalid_response}

      chunk ->
        case chunk do
          :ignore -> :ok
          [] -> :ok
          other -> handler.(other)
        end

        case terminal do
          true ->
            handler.(
              case reason do
                "tool_calls" -> {:function_call_finished}
                _ -> {:tokens_finished}
              end
            )

          false ->
            :ok
        end

        {:ok, terminal}
    end
  end

  defp transport_error(reason) when reason in [:timeout, :recv_timeout],
    do: {:error, :response_timeout}

  defp transport_error(reason)
       when reason in [
              :closed,
              :econnrefused,
              :enetunreach,
              :ehostunreach,
              :nxdomain,
              :connect_timeout
            ],
       do: {:error, :connection_failure}

  defp transport_error(_), do: {:error, :transport_error}
end
