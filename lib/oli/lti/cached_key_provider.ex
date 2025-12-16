defmodule Oli.Lti.CachedKeyProvider do
  @moduledoc """
  ETS-backed implementation of the Lti_1p3.KeyProvider behavior.

  This provider uses an ETS cache (managed by Oli.Lti.KeysetCache) to serve public keys
  without making HTTP requests during student launches. Keys are refreshed out-of-band
  by the Oli.Lti.KeysetRefreshWorker.

  This implementation follows the LTI 1.3 specification's recommendation to cache
  public keys and refresh them periodically rather than fetching just-in-time.

  Features:
  - ETS-backed cache for fast, concurrent access
  - Fallback to HTTP fetch for backwards compatibility
  - Better error messages distinguishing HTTP failures from missing keys
  - Integration with Oban for reliable background key refresh
  """

  @behaviour Lti_1p3.KeyProvider

  require Logger
  alias Oli.Lti.KeysetCache
  alias Oli.Lti.KeysetRefreshWorker

  @http_timeout_ms 10_000
  @default_ttl_seconds 3600

  @impl Lti_1p3.KeyProvider
  def get_public_key(key_set_url, kid) do
    case KeysetCache.get_public_key(key_set_url, kid) do
      {:ok, public_key} ->
        Logger.debug(
          "Cache hit: Found key #{kid} for #{key_set_url} in ETS cache"
        )

        {:ok, public_key}

      {:error, :keyset_not_cached} ->
        Logger.warning(
          "Cache miss: Keyset for #{key_set_url} not cached, falling back to HTTP fetch"
        )

        # Fallback: fetch from HTTP (backwards compatibility)
        # This also handles the case where the worker hasn't run yet
        fetch_and_cache_then_get_key(key_set_url, kid)

      {:error, :key_not_found} ->
        Logger.error(
          "Key #{kid} not found in cached keyset for #{key_set_url}. " <>
            "This may indicate the platform rotated keys. Attempting refresh."
        )

        # Key might have been rotated, try refreshing and checking again
        case refresh_keyset(key_set_url) do
          :ok ->
            case KeysetCache.get_public_key(key_set_url, kid) do
              {:ok, public_key} ->
                Logger.info("Successfully found key #{kid} after refresh")
                {:ok, public_key}

              {:error, :key_not_found} ->
                {:error,
                 %{
                   reason: :key_not_found_in_keyset,
                   msg:
                     "Key with kid '#{kid}' not found in public keyset from #{key_set_url}. " <>
                       "This may indicate a configuration mismatch between the LTI platform and this tool."
                 }}

              {:error, _} ->
                {:error,
                 %{
                   reason: :key_not_found_in_keyset,
                   msg: "Key with kid '#{kid}' not found in public keyset"
                 }}
            end

          {:error, reason} ->
            {:error,
             %{
               reason: :keyset_refresh_failed,
               msg:
                 "Failed to refresh keyset from #{key_set_url}: #{inspect(reason)}. " <>
                   "The platform may be experiencing connectivity issues."
             }}
        end
    end
  end

  @impl Lti_1p3.KeyProvider
  def preload_keys(key_set_url) do
    Logger.info("Preloading keys for #{key_set_url}")

    case refresh_keyset(key_set_url) do
      :ok -> :ok
      {:error, reason} -> {:error, %{reason: reason, msg: "Failed to preload keys"}}
    end
  end

  @impl Lti_1p3.KeyProvider
  def refresh_all_keys do
    Logger.info("Refreshing all LTI registration keysets")

    # Schedule an Oban job to refresh all keysets
    case KeysetRefreshWorker.schedule_refresh_all() do
      {:ok, _job} ->
        # Return empty list since actual refresh happens asynchronously
        # This matches the behavior contract but delegates to Oban
        []

      {:error, reason} ->
        Logger.error("Failed to schedule refresh_all job: #{inspect(reason)}")
        []
    end
  end

  @impl Lti_1p3.KeyProvider
  def clear_cache do
    KeysetCache.clear_cache()
  end

  @impl Lti_1p3.KeyProvider
  def cache_info do
    cached_urls = KeysetCache.list_cached_urls()

    # Get detailed info for each cached URL
    cache_entries =
      Enum.map(cached_urls, fn url ->
        case KeysetCache.get_keyset(url) do
          {:ok, %{keys: keys, fetched_at: fetched_at, expires_at: expires_at}} ->
            {url,
             %{
               key_count: length(keys),
               fetched_at: fetched_at,
               expires_at: expires_at,
               expired: DateTime.compare(DateTime.utc_now(), expires_at) == :gt
             }}

          {:error, _} ->
            {url, %{error: "Failed to retrieve cache entry"}}
        end
      end)
      |> Map.new()

    %{
      total_cached_urls: length(cached_urls),
      cache_entries: cache_entries
    }
  end

  # Private Functions

  defp fetch_and_cache_then_get_key(key_set_url, kid) do
    case refresh_keyset(key_set_url) do
      :ok ->
        case KeysetCache.get_public_key(key_set_url, kid) do
          {:ok, public_key} ->
            {:ok, public_key}

          {:error, :key_not_found} ->
            {:error,
             %{
               reason: :key_not_found_in_keyset,
               msg:
                 "Key with kid '#{kid}' not found in public keyset from #{key_set_url}. " <>
                   "The JWT may be signed with a different key than what the platform provides."
             }}

          {:error, reason} ->
            {:error, %{reason: reason, msg: "Failed to retrieve key from cache after fetch"}}
        end

      {:error, {:http_error, status_code}} ->
        {:error,
         %{
           reason: :http_error,
           msg:
             "HTTP #{status_code} error when fetching public keyset from #{key_set_url}. " <>
               "The platform may be temporarily unavailable or the URL may be incorrect."
         }}

      {:error, {:http_request_failed, reason}} ->
        {:error,
         %{
           reason: :http_request_failed,
           msg:
             "HTTP request failed when fetching public keyset from #{key_set_url}: #{inspect(reason)}. " <>
               "This may be a network connectivity issue or the platform may be down."
         }}

      {:error, :invalid_jwks_format} ->
        {:error,
         %{
           reason: :invalid_jwks_format,
           msg:
             "Invalid JWKS format received from #{key_set_url}. " <>
               "The platform may have a configuration issue."
         }}

      {:error, reason} ->
        {:error,
         %{
           reason: :keyset_fetch_failed,
           msg: "Failed to fetch keyset from #{key_set_url}: #{inspect(reason)}"
         }}
    end
  end

  defp refresh_keyset(key_set_url) do
    case http_get(key_set_url) do
      {:ok, %{status_code: 200, body: body, headers: headers}} ->
        case Jason.decode(body) do
          {:ok, %{"keys" => keys}} when is_list(keys) ->
            ttl = parse_cache_control_max_age(headers)
            KeysetCache.put_keyset(key_set_url, keys, ttl)
            :ok

          {:ok, _invalid_json} ->
            {:error, :invalid_jwks_format}

          {:error, _decode_error} ->
            {:error, :json_decode_failed}
        end

      {:ok, %{status_code: status_code}} ->
        {:error, {:http_error, status_code}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, {:http_request_failed, reason}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp http_get(url) do
    HTTPoison.get(url, [], timeout: @http_timeout_ms, recv_timeout: @http_timeout_ms)
  end

  defp parse_cache_control_max_age(headers) do
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
end
