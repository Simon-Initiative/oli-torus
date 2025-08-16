defmodule Oli.GenAI.Completions.OpenAICompliantProvider do
  alias OpenAI.{Config, Stream}
  require Logger

  @moduledoc """
  An OpenAI compliant provider for chat completions.  Note that this provider
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

    IO.inspect(encode_messages(messages), label: "Messages to OpenAI Compliant Provider")

    api_post(
      config.api_url <> "/v1/chat/completions",
      [
        model: model,
        messages: encode_messages(messages),
        functions: functions
      ],
      config
    ) |> IO.inspect()
  end

  def stream(
        messages,
        functions,
        %RegisteredModel{model: model} = registered_model,
        response_handler_fn
      ) do
    config = config(:async, registered_model)

    case api_post(
           config.api_url <> "/v1/chat/completions",
           [
             model: model,
             messages: encode_messages(messages),
             functions: functions,
             stream: true
           ],
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

      [%{"finish_reason" => "function_call"}] ->
        {:function_call_finished}

      [%{"delta" => %{"function_call" => content}}] ->
        # open ai doesn't have the notion of an id for the function call
        # so we just the key but use nil
        content = Map.put(content, "id", nil)

        {:function_call, content}

      [%{"delta" => %{"content" => content}}] ->
        {:tokens_received, content}

      _ ->
        {:error}
    end
  end

  def encode_messages(messages) do
    # Delete the id and input from messages as open ai does not require these
    # for function calling
    Enum.map(messages, fn message ->
      Map.delete(message, :id)
      |> Map.delete(:input)
    end)
    |> Enum.map(fn message ->
      # Map :tool role to :function for OpenAI compatibility
      role = case message.role do
        :tool -> "function"
        "tool" -> "function"
        other -> other
      end

      case message.name do
        nil -> %{role: role, content: message.content}
        _ -> %{role: role, content: message.content, name: message.name}
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
        Stream.new(fn ->
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
        recv_timeout: registered_model.recv_timeout
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
        async: :once
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

  defp normalize_response(response) when is_map(response) do
    case get_in(response, ["choices", Access.at(0), "message"]) do
      %{"function_call" => function_call} = message ->
        # Convert old function_call format to new tool_calls format
        tool_call = %{
          "id" => "call_" <> Ecto.UUID.generate(),
          "type" => "function",
          "function" => function_call
        }

        normalized_message = message
        |> Map.delete("function_call")
        |> Map.put("tool_calls", [tool_call])

        put_in(response, ["choices", Access.at(0), "message"], normalized_message)

      _ ->
        response
    end
  end

  defp normalize_response(response), do: response
end
