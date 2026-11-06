defmodule Oli.GenAI.Completions.OpenAICompliantProvider do
  require Logger

  @moduledoc "OpenAI request encoding, Provider headers and SSE decoding shared by managed transport and probes."

  def process_stream_chunk(chunk) do
    case chunk["choices"] do
      [] ->
        {:error}

      [%{"finish_reason" => "stop"}] ->
        {:tokens_finished}

      [%{"finish_reason" => "tool_calls"}] ->
        {:function_call_finished}

      [%{"delta" => %{"tool_calls" => tool_calls}}] when is_list(tool_calls) ->
        tool_calls
        |> Enum.map(&decode_tool_call_delta/1)
        |> Enum.reject(&(&1 == :ignore))

      [%{"delta" => %{"role" => _role}}] ->
        :ignore

      [%{"delta" => %{"content" => content}}] ->
        {:tokens_received, content}

      [%{"delta" => delta}] when map_size(delta) == 0 ->
        :ignore

      _ ->
        {:error}
    end
  end

  @doc false
  def completion_params(model, messages, functions, opts \\ []) do
    encoded_messages = encode_messages(messages)

    base = [
      model: model,
      messages: encoded_messages
    ]

    base =
      case functions do
        [] ->
          base

        _ ->
          # Force one tool call at a time; dialogue flow assumes serial function execution.
          base ++ [tools: encode_tools(functions), parallel_tool_calls: false]
      end

    base =
      Enum.reduce([:response_format, :temperature, :max_tokens], base, fn key, acc ->
        case Keyword.fetch(opts, key) do
          {:ok, value} -> acc ++ [{key, value}]
          :error -> acc
        end
      end)

    case Keyword.get(opts, :stream, false) do
      true -> base ++ [stream: true]
      false -> base
    end
  end

  def encode_messages(messages) do
    Enum.flat_map(messages, fn message ->
      case message.role do
        role when role in [:function, "function"] ->
          encode_function_result_messages(message)

        _other ->
          [encode_standard_message(message)]
      end
    end)
  end

  @doc "Adds only the selected Provider organization key, when configured."
  def add_organization_header(headers, config) do
    org_key = config.organization_key

    if org_key do
      [{"OpenAI-Organization", org_key} | headers]
    else
      headers
    end
  end

  def add_beta_header(headers, config) do
    beta = Map.get(config, :beta, nil)

    if beta do
      [{"OpenAI-Beta", beta} | headers]
    else
      headers
    end
  end

  @doc "Builds probe headers from explicit Provider credentials."
  def request_headers(config) do
    [
      bearer(config),
      {"Content-type", "application/json"}
    ]
    |> add_organization_header(config)
    |> add_beta_header(config)
  end

  def bearer(%{api_key: api_key}) when is_binary(api_key) and byte_size(api_key) > 0,
    do: {"Authorization", "Bearer #{api_key}"}

  defp encode_standard_message(message) do
    message
    |> Map.delete(:id)
    |> Map.delete(:input)
    |> then(fn sanitized ->
      role =
        case sanitized.role do
          :tool -> "tool"
          "tool" -> "tool"
          other -> other
        end

      base = %{role: role, content: sanitized.content}

      base =
        case Map.get(sanitized, :name) do
          nil -> base
          name -> Map.put(base, :name, name)
        end

      case Map.get(sanitized, :tool_call_id) do
        nil -> base
        tool_call_id -> Map.put(base, :tool_call_id, tool_call_id)
      end
    end)
  end

  defp encode_function_result_messages(message) do
    encoded_args = Jason.encode!(message.input || %{})
    tool_call_id = message.id || new_tool_call_id()

    [
      %{
        role: "assistant",
        tool_calls: [
          %{
            id: tool_call_id,
            type: "function",
            function: %{
              name: message.name,
              arguments: encoded_args
            }
          }
        ]
      },
      %{
        role: "tool",
        tool_call_id: tool_call_id,
        content: message.content
      }
    ]
  end

  defp encode_tools(functions) do
    Enum.map(functions, fn function ->
      %{
        type: "function",
        function: %{
          name: function.name,
          description: function.description,
          parameters: function.parameters
        }
      }
    end)
  end

  defp decode_tool_call_delta(
         %{"function" => %{"name" => name, "arguments" => arguments}} = tool_call
       )
       when is_binary(name) and is_binary(arguments) do
    {:function_call,
     %{
       "id" => Map.get(tool_call, "id", new_tool_call_id()),
       "name" => name,
       "arguments" => arguments
     }}
  end

  defp decode_tool_call_delta(%{"function" => %{"arguments" => arguments}})
       when is_binary(arguments) do
    {:function_call, %{"arguments" => arguments}}
  end

  defp decode_tool_call_delta(%{"function" => %{"name" => name}} = tool_call)
       when is_binary(name) do
    {:function_call,
     %{
       "id" => Map.get(tool_call, "id", new_tool_call_id()),
       "name" => name,
       "arguments" => ""
     }}
  end

  defp decode_tool_call_delta(_), do: :ignore

  # Some OpenAI-compatible providers cap tool_call IDs at 40 chars.
  # "call" (4) + UUID (36) = 40.
  defp new_tool_call_id do
    "call" <> Ecto.UUID.generate()
  end

  @doc false
  def decode_stream_chunk(buffer, chunk) do
    {events, rest} =
      buffer
      |> Kernel.<>(chunk)
      |> String.replace("\r\n", "\n")
      |> split_sse_events()

    data =
      events
      |> Enum.flat_map(&decode_sse_event/1)

    {data, rest}
  end

  defp split_sse_events(data) do
    parts = String.split(data, "\n\n")

    case {parts, String.ends_with?(data, "\n\n")} do
      {[_], false} ->
        {[], data}

      {parts, true} ->
        {Enum.reject(parts, &(&1 == "")), ""}

      {parts, false} ->
        {complete, [rest]} = Enum.split(parts, length(parts) - 1)
        {Enum.reject(complete, &(&1 == "")), rest}
    end
  end

  defp decode_sse_event(event) do
    event
    |> extract_sse_payload_lines()
    |> decode_sse_payload_lines()
  end

  defp extract_sse_data_line("data:" <> rest) do
    [String.trim_leading(rest, " ")]
  end

  defp extract_sse_data_line(_line) do
    []
  end

  defp extract_sse_payload_lines(event) do
    event
    |> String.split("\n")
    |> Enum.flat_map(&extract_sse_data_line/1)
  end

  defp decode_sse_payload_lines([]) do
    []
  end

  defp decode_sse_payload_lines(["[DONE]"]) do
    []
  end

  defp decode_sse_payload_lines(payload_lines) do
    payload = Enum.join(payload_lines, "\n")

    try do
      [Jason.decode!(payload)]
    rescue
      error in Jason.DecodeError ->
        Logger.error("GenAI stream payload decode failure error_category=invalid_json")
        reraise error, __STACKTRACE__
    end
  end
end
