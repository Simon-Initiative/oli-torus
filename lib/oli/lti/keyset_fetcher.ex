defmodule Oli.Lti.KeysetFetcher do
  @moduledoc """
  Shared JWKS fetch-and-cache boundary for LTI platform public keys.
  """

  require Logger

  alias Oli.Lti.KeysetCache

  @default_ttl_seconds 3600
  @http_timeout_ms 10_000

  @spec fetch_and_cache(String.t()) ::
          {:ok,
           %{
             keys: list(),
             fetched_at: DateTime.t(),
             expires_at: DateTime.t(),
             ttl_seconds: non_neg_integer()
           }}
          | {:error, term()}
  def fetch_and_cache(key_set_url) do
    with :ok <- validate_https_url(key_set_url),
         {:ok, response} <- http_get(key_set_url),
         {:ok, %{keys: keys, ttl_seconds: ttl_seconds}} <- parse_response(response, key_set_url),
         :ok <- KeysetCache.put_keyset(key_set_url, keys, ttl_seconds),
         {:ok, %{fetched_at: fetched_at, expires_at: expires_at}} <-
           KeysetCache.get_keyset(key_set_url) do
      {:ok,
       %{
         keys: keys,
         fetched_at: fetched_at,
         expires_at: expires_at,
         ttl_seconds: ttl_seconds
       }}
    end
  end

  @spec validate_https_url(String.t()) :: :ok | {:error, atom()}
  def validate_https_url(url) do
    uri = URI.parse(url)

    cond do
      is_nil(uri.scheme) ->
        Logger.error("Invalid URL: No scheme provided for #{url}")
        {:error, :invalid_url_no_scheme}

      uri.scheme != "https" ->
        Logger.error("Insecure URL: Only HTTPS URLs are allowed, got #{uri.scheme}://")
        {:error, :insecure_url_scheme}

      is_nil(uri.host) or uri.host == "" ->
        Logger.error("Invalid URL: No host provided for #{url}")
        {:error, :invalid_url_no_host}

      true ->
        :ok
    end
  end

  @spec parse_cache_control_max_age(list()) :: non_neg_integer()
  def parse_cache_control_max_age(headers) do
    headers
    |> Enum.find_value(fn
      {"cache-control", value} -> value
      {"Cache-Control", value} -> value
      _ -> nil
    end)
    |> case do
      nil ->
        @default_ttl_seconds

      cache_control ->
        case Regex.run(~r/max-age=(\d+)/, cache_control) do
          [_, max_age_str] -> String.to_integer(max_age_str)
          _ -> @default_ttl_seconds
        end
    end
  end

  defp parse_response(%{status_code: 200, body: body, headers: headers}, key_set_url) do
    case Jason.decode(body) do
      {:ok, %{"keys" => keys}} when is_list(keys) ->
        {:ok, %{keys: keys, ttl_seconds: parse_cache_control_max_age(headers)}}

      {:ok, invalid_json} ->
        Logger.error(
          "Invalid JWKS format from #{key_set_url}: missing 'keys' array. Body: #{inspect(invalid_json)}"
        )

        {:error, :invalid_jwks_format}

      {:error, decode_error} ->
        Logger.error("Failed to decode JSON from #{key_set_url}: #{inspect(decode_error)}")
        {:error, :json_decode_failed}
    end
  end

  defp parse_response(%{status_code: status_code}, _key_set_url) do
    {:error, {:http_error, status_code}}
  end

  defp http_get(url) do
    http_client = Lti_1p3.Config.http_client!()
    http_client.get(url, [], timeout: @http_timeout_ms, recv_timeout: @http_timeout_ms)
  end
end
