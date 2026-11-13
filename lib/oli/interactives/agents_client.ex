defmodule Oli.Interactives.AgentsClient do
  @moduledoc """
  Small Agents API adapter adapted from Nimoy's `AgentConsole.Providers.OpenAI`.

  Uses Torus's existing HTTPoison dependency, independently of its GenAI infrastructure.
  Credentials are read from `OPENAI_API_KEY` at request time and never sent into a sandbox.
  Requests are not retried or redirected: an ambiguous mutation must not create duplicate work.
  """

  @base_url "https://api.openai.com/v1/agents"
  @type result :: {:ok, map() | binary()} | {:error, map()}

  @doc "Lists published artifacts with pagination metadata for a completed session turn."
  @spec artifacts_page(String.t(), String.t() | nil, keyword()) :: result()
  def artifacts_page(id, after_id \\ nil, opts \\ []) do
    query = URI.encode_query(%{order: "asc", limit: 100})

    cursor =
      case after_id do
        nil -> ""
        value -> "&after=" <> encode(value)
      end

    session_request(:get, id, "/artifacts?" <> query <> cursor, nil, opts)
  end

  @doc "Downloads immutable artifact bytes. Callers must first check the artifact's size and turn."
  @spec artifact_content(String.t(), String.t(), keyword()) :: result()
  def artifact_content(id, artifact_id, opts \\ []) do
    with :ok <- valid_id(artifact_id) do
      session_request(
        :get,
        id,
        "/artifacts/" <> encode(artifact_id) <> "/content",
        nil,
        Keyword.put(opts, :raw_response, true)
      )
    end
  end

  @doc "Acknowledges an application function call using the provider's turn and call identifiers."
  @spec submit_tool_result(String.t(), map(), keyword()) :: result()
  def submit_tool_result(id, action, opts \\ []) do
    event = %{
      "type" => "agent.session.input.tool_result",
      "turn_id" => action["turn_id"],
      "call_id" => action["call_id"],
      "success" => true,
      "output" =>
        "Handoff registered. End your turn so the ZIP is published. Torus will retrieve it and save the activity."
    }

    session_request(:post, id, "/events", %{"events" => [event]}, opts)
  end

  @doc "Starts an OpenAI-hosted session and returns immediately, without owning an event stream."
  @spec start_session(map(), keyword()) :: result()
  def start_session(body, opts \\ [])

  def start_session(%{"environment" => %{"type" => "openai_hosted"}} = body, opts),
    do: request(:post, "/sessions", Map.put(body, "stream", false), opts)

  def start_session(_, _),
    do: failure(:configuration, "Interactives require an OpenAI-hosted environment.")

  @doc "Retrieves the provider's current session, including environment and required actions."
  @spec get_session(String.t(), keyword()) :: result()
  def get_session(id, opts \\ []), do: session_request(:get, id, "", nil, opts)

  @doc "Retrieves hosted environment provisioning status. A created session is not yet ready."
  @spec get_environment(String.t(), keyword()) :: result()
  def get_environment(id, opts \\ []) do
    with :ok <- valid_id(id) do
      request(:get, "/environments/" <> encode(id), nil, opts)
    end
  end

  @doc "Lists saved items in ascending order, preserving the provider's pagination metadata."
  @spec items_page(String.t(), String.t() | nil, keyword()) :: result()
  def items_page(id, after_id \\ nil, opts \\ []) do
    query = URI.encode_query(%{order: Keyword.get(opts, :order, "asc"), limit: 100})

    cursor =
      case after_id do
        nil -> ""
        cursor -> "&after=" <> encode(cursor)
      end

    session_request(:get, id, "/items?" <> query <> cursor, nil, opts)
  end

  @doc "Retrieves the most recent turn so callers can distinguish completion from an idle session."
  @spec latest_turn(String.t(), keyword()) :: result()
  def latest_turn(id, opts \\ []),
    do: session_request(:get, id, "/turns?order=desc&limit=1", nil, opts)

  @doc "Submits another message; an optional `:idempotency_key` identifies this input operation."
  @spec submit_input(String.t(), String.t(), keyword()) :: result()
  def submit_input(id, input, opts \\ []) do
    event = %{
      "type" => "agent.session.input.message",
      "input" => [
        %{
          "type" => "message",
          "role" => "user",
          "content" => [%{"type" => "input_text", "text" => input}]
        }
      ]
    }

    session_request(:post, id, "/events", %{"events" => [event]}, opts)
  end

  @doc "Requests cancellation of the active turn. Acceptance does not mean cancellation is complete."
  @spec cancel_session(String.t(), keyword()) :: result()
  def cancel_session(id, opts \\ []) do
    body = %{"events" => [%{"type" => "agent.session.input.cancel"}]}
    session_request(:post, id, "/events", body, opts)
  end

  @doc "Deletes a finished session and requests sandbox cleanup; active work must be cancelled first."
  @spec delete_session(String.t(), keyword()) :: result()
  def delete_session(id, opts \\ []), do: session_request(:delete, id, "", nil, opts)

  defp session_request(method, id, suffix, body, opts) do
    with :ok <- valid_id(id) do
      request(method, "/sessions/" <> encode(id) <> suffix, body, opts)
    end
  end

  defp request(method, path, body, opts) do
    with {:ok, key} <- credential(opts) do
      headers = [
        {"authorization", "Bearer " <> key},
        {"openai-beta", "agents=v1"},
        {"content-type", "application/json"}
      ]

      headers =
        case Keyword.get(opts, :idempotency_key) do
          nil -> headers
          key -> [{"idempotency-key", key} | headers]
        end

      encoded_body =
        case body do
          nil -> ""
          body -> Jason.encode!(body)
        end

      http = Keyword.get(opts, :http_client, HTTPoison)

      case http.request(method, @base_url <> path, encoded_body, headers,
             timeout: 10_000,
             recv_timeout: 30_000,
             follow_redirect: false
           ) do
        {:ok, %{status_code: 202, body: ""}} when method == :post ->
          {:ok, %{}}

        {:ok, %{status_code: status, body: response_body}} when status in 200..299 ->
          case Keyword.get(opts, :raw_response, false) do
            true ->
              {:ok, response_body}

            false ->
              case Jason.decode(response_body) do
                {:ok, data} when is_map(data) -> {:ok, data}
                _ -> failure(:protocol, "OpenAI returned an unexpected response.", method != :get)
              end
          end

        {:ok, %{status_code: status, headers: response_headers}} ->
          request_id =
            Enum.find_value(response_headers, fn {name, value} ->
              case String.downcase(name) do
                "x-request-id" -> value
                _ -> nil
              end
            end)

          failure(
            :http,
            "OpenAI returned HTTP #{status}. Check project access and request configuration.",
            method != :get and (status == 408 or status >= 500),
            %{status: status, request_id: request_id}
          )

        {:error, _} ->
          failure(
            :transport,
            "OpenAI could not be reached; remote state may be uncertain.",
            method != :get
          )
      end
    end
  end

  defp credential(opts) do
    case Keyword.get(opts, :api_key, System.get_env("OPENAI_API_KEY")) do
      key when is_binary(key) and byte_size(key) > 0 -> {:ok, key}
      _ -> failure(:configuration, "Set OPENAI_API_KEY in the server environment.")
    end
  end

  defp valid_id(id) when is_binary(id) and byte_size(id) > 0, do: :ok
  defp valid_id(_), do: failure(:configuration, "A provider ID is required.")
  defp encode(id), do: URI.encode(id, &URI.char_unreserved?/1)

  defp failure(kind, message, uncertain \\ false, details \\ %{}) do
    {:error,
     Map.merge(
       %{
         kind: kind,
         message: message,
         status: nil,
         request_id: nil,
         creation_uncertain: uncertain
       },
       details
     )}
  end
end
