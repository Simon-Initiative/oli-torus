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
  alias Oli.Lti.KeysetFetchCoordinator
  alias Oli.Lti.KeysetFetcher
  alias Oli.Lti.KeysetRefreshWorker

  @impl Lti_1p3.KeyProvider
  def get_public_key(key_set_url, kid) do
    case KeysetCache.get_public_key(key_set_url, kid) do
      {:ok, public_key} ->
        log_lookup("warm_cache_hit", %{
          key_set_url: key_set_url,
          requested_kid: kid,
          lookup_source: :warm_cache,
          outcome: :success
        })

        {:ok, public_key}

      {:error, :keyset_not_cached} ->
        Logger.info("Cache miss for #{key_set_url}; attempting synchronous keyset fetch")
        refresh_and_retry_lookup(key_set_url, kid, :cold_cache)

      {:error, :key_not_found} ->
        Logger.error(
          "Key #{kid} not found in cached keyset for #{key_set_url}. " <>
            "Attempting synchronous keyset refresh."
        )

        refresh_and_retry_lookup(key_set_url, kid, :cached_key_miss)
    end
  end

  @impl Lti_1p3.KeyProvider
  def preload_keys(key_set_url) do
    Logger.info("Preloading keys for #{key_set_url}")

    # preload_keys is explicitly called (not during launches), so synchronous fetch is acceptable
    case KeysetFetcher.fetch_and_cache(key_set_url) do
      {:ok, _result} -> :ok
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

  defp refresh_and_retry_lookup(key_set_url, kid, refresh_context) do
    cached_keyset_before_refresh =
      case KeysetCache.get_keyset(key_set_url) do
        {:ok, keyset} -> keyset
        _ -> nil
      end

    fetch =
      KeysetFetchCoordinator.run_with_metadata(key_set_url, fn ->
        KeysetFetcher.fetch_and_cache(key_set_url)
      end)

    case fetch.result do
      {:ok, fetched_keyset} ->
        handle_post_refresh_lookup(
          key_set_url,
          kid,
          refresh_context,
          fetch.role,
          cached_keyset_before_refresh,
          fetched_keyset
        )

      {:error, reason} ->
        log_lookup("sync_lookup_failed", %{
          key_set_url: key_set_url,
          requested_kid: kid,
          lookup_source: lookup_source(refresh_context),
          single_flight_role: fetch.role,
          cached_key_ids_before_refresh: key_ids(cached_keyset_before_refresh),
          refreshed_key_ids: [],
          outcome: reason
        })

        {:error, fetch_error(reason, key_set_url, kid, refresh_context)}
    end
  end

  defp handle_post_refresh_lookup(
         key_set_url,
         kid,
         refresh_context,
         role,
         cached_keyset_before_refresh,
         fetched_keyset
       ) do
    case KeysetCache.get_public_key(key_set_url, kid) do
      {:ok, public_key} ->
        log_lookup("sync_lookup_success", %{
          key_set_url: key_set_url,
          requested_kid: kid,
          lookup_source: lookup_source(refresh_context),
          single_flight_role: role,
          cached_key_ids_before_refresh: key_ids(cached_keyset_before_refresh),
          refreshed_key_ids: key_ids(fetched_keyset),
          cache_fetched_at: fetched_keyset.fetched_at,
          cache_expires_at: fetched_keyset.expires_at,
          outcome: :success
        })

        {:ok, public_key}

      {:error, :key_not_found} ->
        log_lookup("sync_lookup_failed", %{
          key_set_url: key_set_url,
          requested_kid: kid,
          lookup_source: lookup_source(refresh_context),
          single_flight_role: role,
          cached_key_ids_before_refresh: key_ids(cached_keyset_before_refresh),
          refreshed_key_ids: key_ids(fetched_keyset),
          outcome: :key_not_found_in_keyset
        })

        {:error, key_not_found_error(key_set_url, kid, refresh_context)}

      {:error, :keyset_not_cached} ->
        log_lookup("sync_lookup_failed", %{
          key_set_url: key_set_url,
          requested_kid: kid,
          lookup_source: lookup_source(refresh_context),
          single_flight_role: role,
          cached_key_ids_before_refresh: key_ids(cached_keyset_before_refresh),
          refreshed_key_ids: key_ids(fetched_keyset),
          outcome: :keyset_not_cached
        })

        {:error, fetch_error(:keyset_not_cached, key_set_url, kid, refresh_context)}
    end
  end

  defp key_ids(nil), do: []

  defp key_ids(%{keys: keys}) do
    Enum.map(keys, &Map.get(&1, "kid"))
  end

  defp lookup_source(:cold_cache), do: :sync_cold_fill
  defp lookup_source(:cached_key_miss), do: :sync_refresh_after_kid_miss

  defp log_lookup(event, metadata) do
    Logger.info("lti_keyset_lookup #{event} #{inspect(metadata)}")
  end

  defp key_not_found_error(key_set_url, kid, :cold_cache) do
    %{
      reason: :key_not_found_in_keyset,
      msg:
        "Key with kid '#{kid}' was not found in the keyset fetched from #{key_set_url}. " <>
          "Torus fetched the latest available keys for this launch, but the requested signing key was still unavailable."
    }
  end

  defp key_not_found_error(key_set_url, kid, :cached_key_miss) do
    %{
      reason: :key_not_found_in_keyset,
      msg:
        "Key with kid '#{kid}' was not found after refreshing the keyset from #{key_set_url}. " <>
          "Torus retried with the latest available keys for this launch, but the requested signing key was still unavailable."
    }
  end

  defp fetch_error(reason, key_set_url, kid, refresh_context) do
    %{
      reason: reason,
      msg: fetch_error_message(reason, key_set_url, kid, refresh_context)
    }
  end

  defp fetch_error_message({:http_error, status_code}, key_set_url, _kid, refresh_context) do
    "Torus could not fetch a usable keyset from #{key_set_url} during #{describe_refresh_context(refresh_context)} " <>
      "because the JWKS endpoint returned HTTP #{status_code}."
  end

  defp fetch_error_message(:json_decode_failed, key_set_url, _kid, refresh_context) do
    "Torus could not decode the JWKS response from #{key_set_url} during #{describe_refresh_context(refresh_context)}."
  end

  defp fetch_error_message(:invalid_jwks_format, key_set_url, _kid, refresh_context) do
    "Torus fetched #{key_set_url} during #{describe_refresh_context(refresh_context)}, but the response was not a valid JWKS payload."
  end

  defp fetch_error_message(:invalid_url_no_scheme, key_set_url, _kid, _refresh_context) do
    "The configured JWKS URL '#{key_set_url}' is invalid because it has no URL scheme."
  end

  defp fetch_error_message(:insecure_url_scheme, key_set_url, _kid, _refresh_context) do
    "The configured JWKS URL '#{key_set_url}' is invalid because Torus only allows HTTPS keyset URLs."
  end

  defp fetch_error_message(:invalid_url_no_host, key_set_url, _kid, _refresh_context) do
    "The configured JWKS URL '#{key_set_url}' is invalid because it has no host."
  end

  defp fetch_error_message(:keyset_not_cached, key_set_url, kid, refresh_context) do
    "Torus refreshed #{key_set_url} during #{describe_refresh_context(refresh_context)}, " <>
      "but the requested key '#{kid}' was still unavailable from cache."
  end

  defp fetch_error_message(:single_flight_timeout, key_set_url, _kid, refresh_context) do
    "Torus timed out while waiting for a shared keyset fetch from #{key_set_url} during #{describe_refresh_context(refresh_context)}."
  end

  defp fetch_error_message(:single_flight_owner_down, key_set_url, _kid, refresh_context) do
    "Torus could not complete the shared keyset fetch from #{key_set_url} during #{describe_refresh_context(refresh_context)} because the fetch owner exited before finishing."
  end

  defp fetch_error_message(reason, key_set_url, _kid, refresh_context) do
    "Torus could not refresh the keyset from #{key_set_url} during #{describe_refresh_context(refresh_context)}: #{inspect(reason)}"
  end

  defp describe_refresh_context(:cold_cache), do: "launch-time cache fill"
  defp describe_refresh_context(:cached_key_miss), do: "launch-time key refresh"
end
