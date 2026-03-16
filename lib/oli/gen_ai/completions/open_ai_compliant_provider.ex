defmodule Oli.GenAI.Completions.OpenAICompliantProvider do
  alias OpenAI.Config
  require Logger

  @moduledoc """
  An OpenAI compliant provider for chat completions. Note that this provider
  is a bit of a "clone and own" of internal code from the :openai library. That library
  has a limitation in that you cannot actually override the base URL, which makes it
  impossible to use with custom OpenAI compliant providers. This provider is
  designed to be used with OpenAI itself AND compliant models that support the
  OpenAI chat completions API.
  """

  import HTTPoison, only: [post: 4]

  @behaviour Oli.GenAI.Completions.Provider

  alias Oli.GenAI.Completions.RegisteredModel

  def generate(messages, functions, %RegisteredModel{model: model} = registered_model) do
    config = config(:sync, registered_model)
    params = completion_params(model, messages, functions)

    case api_post(config.api_url <> "/v1/chat/completions", params, config) do
      {:ok, response} ->
        extract_content(response)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def stream(
        messages,
        functions,
        %RegisteredModel{model: model} = registered_model,
        response_handler_fn
      ) do
    config = config(:async, registered_model)
    params = completion_params(model, messages, functions, stream: true)

    case api_post(
           config.api_url <> "/v1/chat/completions",
           params,
           config
         ) do
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("OpenAI Provider HTTP failure: #{inspect(reason)}")
        {:error, reason}

      stream ->
        stream
        |> Elixir.Stream.transform(:ok, fn chunk, :ok ->
          case process_stream_chunk(chunk) do
            {:error} ->
              response_handler_fn.({:error})
              {:halt, {:error}}

            :ignore ->
              {[], :ok}

            other ->
              response_handler_fn.(other)
              {[], :ok}
          end
        end)
        |> Elixir.Stream.run()
    end
  end

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

  def process_response_body(body) do
    try do
      {status, res} = Jason.decode(body)

      case status do
        :ok ->
          {:ok, res}

        :error ->
          body
      end
    rescue
      _ ->
        body
    end
  end

  def handle_response(httpoison_response) do
    case httpoison_response do
      {:ok, %HTTPoison.Response{status_code: 200, body: {:ok, body}}} ->
        res =
          body
          |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
          |> Map.new()

        {:ok, normalize_response(res)}

      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, normalize_response(body)}

      {:ok, %HTTPoison.Response{body: {:ok, body}}} ->
        {:error, body}

      {:ok, %HTTPoison.Response{body: {:error, body}}} ->
        {:error, body}

      # html error responses
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        {:error, %{status_code: status_code, body: body}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  def add_organization_header(headers, config) do
    org_key = config.organization_key || Config.org_key()

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

  def request_headers(config) do
    [
      bearer(config),
      {"Content-type", "application/json"}
    ]
    |> add_organization_header(config)
    |> add_beta_header(config)
  end

  def bearer(config), do: {"Authorization", "Bearer #{config.api_key || Config.api_key()}"}

  def request_options(config), do: config.http_options || Config.http_options()

  def stream_request_options(config) do
    http_options = request_options(config)

    case http_options[:stream_to] do
      nil ->
        http_options ++ [stream_to: self()]

      _ ->
        http_options
    end
  end

  def api_post(url, params \\ [], config) do
    body =
      params
      |> Enum.into(%{})
      |> Jason.encode!()

    case params |> Keyword.get(:stream, false) do
      true ->
        stream_response(fn ->
          url
          |> post(body, request_headers(config), stream_request_options(config))
        end)

      false ->
        url
        |> post(body, request_headers(config), request_options(config))
        |> handle_response()
    end
  end

  defp config(:sync, %RegisteredModel{} = registered_model) do
    url =
      Oli.GenAI.Completions.Utils.realize_url(registered_model.url_template, %{
        "model" => registered_model.model,
        "api_key" => registered_model.api_key,
        "secondary_api_key" => registered_model.secondary_api_key
      })

    %OpenAI.Config{
      http_options: [
        timeout: registered_model.timeout,
        recv_timeout: registered_model.recv_timeout,
        hackney: [pool: Oli.GenAI.HackneyPool.pool_name(registered_model)]
      ],
      api_key: registered_model.api_key,
      organization_key: registered_model.secondary_api_key,
      api_url: url
    }
  end

  defp config(:async, %RegisteredModel{} = registered_model) do
    url =
      Oli.GenAI.Completions.Utils.realize_url(registered_model.url_template, %{
        "model" => registered_model.model,
        "api_key" => registered_model.api_key,
        "secondary_api_key" => registered_model.secondary_api_key
      })

    %OpenAI.Config{
      http_options: [
        timeout: registered_model.timeout,
        recv_timeout: registered_model.recv_timeout,
        stream_to: self(),
        async: :once,
        hackney: [pool: Oli.GenAI.HackneyPool.pool_name(registered_model)]
      ],
      api_key: registered_model.api_key,
      organization_key: registered_model.secondary_api_key,
      api_url: url
    }
  end

  # Normalize OpenAI response to consistent format
  defp normalize_response(response) when is_binary(response) do
    case Jason.decode(response) do
      {:ok, parsed} -> normalize_response(parsed)
      {:error, _} -> response
    end
  end

  defp normalize_response(response) when is_map(response), do: response

  defp normalize_response(response), do: response

  defp extract_content(response) do
    response = decode_response(response)

    case response do
      %{"choices" => [%{"message" => %{"content" => content}} | _]}
      when is_binary(content) ->
        {:ok, content}

      %{choices: [%{message: %{content: content}} | _]} when is_binary(content) ->
        {:ok, content}

      _ ->
        Logger.error("Unexpected OpenAI response format: #{inspect(response)}")
        {:error, :unexpected_response}
    end
  end

  defp decode_response(response) when is_binary(response) do
    case Jason.decode(response) do
      {:ok, parsed} -> parsed
      {:error, _} -> response
    end
  end

  defp decode_response(response), do: response

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
        case sanitized.name do
          nil -> base
          _ -> Map.put(base, :name, sanitized.name)
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

  defp stream_response(start_fun) do
    Stream.resource(
      start_fun,
      fn
        {:error, %HTTPoison.Error{} = error} ->
          {
            [
              %{
                "status" => :error,
                "reason" => error.reason
              }
            ],
            error
          }

        %HTTPoison.Error{} = error ->
          {:halt, error}

        {:ok, res = %HTTPoison.AsyncResponse{id: id}} ->
          handle_stream_event(%{
            response: res,
            id: id,
            buffer: "",
            error_status_code: nil,
            error_body: ""
          })

        res = %HTTPoison.AsyncResponse{id: id} ->
          handle_stream_event(%{
            response: res,
            id: id,
            buffer: "",
            error_status_code: nil,
            error_body: ""
          })

        %{halted: true} = state ->
          {:halt, state}

        %{response: %HTTPoison.AsyncResponse{}, id: _id, buffer: _buffer} = state ->
          handle_stream_event(state)
      end,
      fn
        %{id: id} ->
          :hackney.stop_async(id)

          :ok

        _ ->
          :ok
      end
    )
  end

  defp handle_stream_event(
         %{
           response: res,
           id: id,
           buffer: buffer,
           error_status_code: error_status_code
         } = state
       ) do
    receive do
      %HTTPoison.AsyncStatus{id: ^id, code: 200} = message ->
        HTTPoison.stream_next(res)
        advance_stream_state(state, process_async_stream_message(message, buffer))

      %HTTPoison.AsyncStatus{id: ^id, code: code} ->
        HTTPoison.stream_next(res)
        {[], %{state | error_status_code: code, error_body: ""}}

      %HTTPoison.AsyncHeaders{id: ^id} = message ->
        HTTPoison.stream_next(res)

        case error_status_code do
          nil ->
            advance_stream_state(state, process_async_stream_message(message, buffer))

          _ ->
            {[], state}
        end

      %HTTPoison.AsyncChunk{id: ^id} = message ->
        HTTPoison.stream_next(res)

        case error_status_code do
          nil ->
            advance_stream_state(state, process_async_stream_message(message, buffer))

          _ ->
            {[], accumulate_error_body(state, message.chunk)}
        end

      %HTTPoison.AsyncEnd{id: ^id} = message ->
        case error_status_code do
          nil ->
            advance_stream_state(state, process_async_stream_message(message, buffer))

          code ->
            advance_stream_state(
              state,
              {:emit_and_halt, [status_error_chunk(code, state.error_body)]}
            )
        end

      %HTTPoison.Error{id: ^id} = message ->
        advance_stream_state(state, process_async_stream_message(message, buffer))
    end
  end

  @doc false
  def process_async_stream_message(%HTTPoison.AsyncStatus{code: 200}, buffer) do
    {:continue, [], buffer}
  end

  def process_async_stream_message(%HTTPoison.AsyncStatus{code: code}, buffer) do
    {:continue, [status_error_chunk(code)], buffer}
  end

  def process_async_stream_message(%HTTPoison.AsyncHeaders{}, buffer) do
    {:continue, [], buffer}
  end

  def process_async_stream_message(%HTTPoison.AsyncChunk{chunk: chunk}, buffer) do
    {data, next_buffer} = decode_stream_chunk(buffer, chunk)
    {:continue, data, next_buffer}
  end

  def process_async_stream_message(%HTTPoison.AsyncEnd{}, buffer) do
    case finalize_stream_buffer(buffer) do
      [] ->
        {:halt}

      {:error, reason} ->
        {:emit_and_halt, [reason_error_chunk(reason)]}

      data ->
        {:emit_and_halt, data}
    end
  end

  def process_async_stream_message(%HTTPoison.Error{reason: reason}, _buffer) do
    {:emit_and_halt, [reason_error_chunk(reason)]}
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

  defp advance_stream_state(state, {:continue, data, next_buffer}) do
    {data, %{state | buffer: next_buffer}}
  end

  defp advance_stream_state(state, {:emit_and_halt, data}) do
    {data, state |> Map.put(:buffer, "") |> Map.put(:halted, true)}
  end

  defp advance_stream_state(state, {:halt}) do
    {:halt, state}
  end

  defp finalize_stream_buffer(buffer) do
    case String.trim(buffer) do
      "" ->
        []

      remaining ->
        case extract_sse_payload_lines(remaining) do
          [] ->
            {:error, :incomplete_sse_event}

          ["[DONE]"] ->
            []

          payload_lines ->
            try do
              decode_sse_payload_lines(payload_lines)
            rescue
              Jason.DecodeError ->
                {:error, :incomplete_sse_event}
            end
        end
    end
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
        Logger.error("GenAI raw stream payload decode failure: #{inspect(payload)}")
        reraise error, __STACKTRACE__
    end
  end

  defp reason_error_chunk(reason) do
    %{
      "status" => :error,
      "reason" => reason,
      "choices" => []
    }
  end

  defp status_error_chunk(code) do
    %{
      "status" => :error,
      "code" => code,
      "choices" => []
    }
  end

  defp status_error_chunk(code, body) do
    %{
      "status" => :error,
      "code" => code,
      "body" => body,
      "choices" => []
    }
  end

  defp accumulate_error_body(state, chunk) do
    %{state | error_body: state.error_body <> chunk}
  end
end
