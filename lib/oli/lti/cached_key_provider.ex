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
        Logger.debug("Cache hit: Found key #{kid} for #{key_set_url} in ETS cache")
        {:ok, public_key}

      {:error, :keyset_not_cached} ->
        Logger.error(
          "Cache miss: Keyset for #{key_set_url} not cached. " <>
            "The background worker has not yet fetched keys for this platform. " <>
            "Scheduling immediate refresh."
        )

        # Schedule a refresh for next time, but fail this request fast
        schedule_refresh_for_url(key_set_url)

        {:error,
         %{
           reason: :keyset_not_cached,
           msg:
             "Public keys for #{key_set_url} are not yet cached. " <>
               "A background job has been scheduled to fetch them. " <>
               "Please try the launch again in a few moments, or contact your administrator."
         }}

      {:error, :key_not_found} ->
        Logger.error(
          "Key #{kid} not found in cached keyset for #{key_set_url}. " <>
            "This may indicate the platform rotated keys. Scheduling immediate refresh."
        )

        # Schedule a refresh for next time, but fail this request fast
        schedule_refresh_for_url(key_set_url)

        {:error,
         %{
           reason: :key_not_found_in_keyset,
           msg:
             "Key with kid '#{kid}' not found in the cached keyset from #{key_set_url}. " <>
               "This may indicate the platform rotated its keys. " <>
               "A background job has been scheduled to fetch the updated keys. " <>
               "Please try the launch again in a few moments."
         }}
    end
  end

  @impl Lti_1p3.KeyProvider
  def preload_keys(key_set_url) do
    Logger.info("Preloading keys for #{key_set_url}")

    # preload_keys is explicitly called (not during launches), so synchronous fetch is acceptable
    case refresh_keyset_sync(key_set_url) do
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

  defp schedule_refresh_for_url(key_set_url) do
    # Find registration(s) with this key_set_url and schedule refresh
    # Note: Multiple registrations might share the same key_set_url
    case find_registration_by_key_set_url(key_set_url) do
      nil ->
        Logger.warning(
          "No registration found for key_set_url #{key_set_url}, cannot schedule refresh"
        )

        :ok

      registration ->
        Logger.info("Scheduling immediate refresh for registration #{registration.id}")

        case KeysetRefreshWorker.schedule_refresh(registration.id) do
          {:ok, _job} -> :ok
          {:error, reason} -> Logger.error("Failed to schedule refresh: #{inspect(reason)}")
        end
    end
  end

  defp find_registration_by_key_set_url(key_set_url) do
    import Ecto.Query

    Oli.Lti.Tool.Registration
    |> where([r], r.key_set_url == ^key_set_url)
    |> limit(1)
    |> Oli.Repo.one()
  end

  # Synchronous refresh functions - ONLY used by preload_keys (not in launch path)

  defp refresh_keyset_sync(key_set_url) do
    with :ok <- validate_https_url(key_set_url),
         {:ok, response} <- http_get(key_set_url) do
      handle_http_response(response, key_set_url)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_http_response(%{status_code: 200, body: body, headers: headers}, key_set_url) do
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
  end

  defp handle_http_response(%{status_code: status_code}, _key_set_url) do
    {:error, {:http_error, status_code}}
  end

  defp http_get(url) do
    http_client = Lti_1p3.Config.http_client!()
    http_client.get(url, [], timeout: @http_timeout_ms, recv_timeout: @http_timeout_ms)
  end

  defp validate_https_url(url) do
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
