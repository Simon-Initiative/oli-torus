defmodule Oli.Lti.KeysetRefreshWorker do
  @moduledoc """
  Oban worker that fetches and caches LTI platform public keysets.

  This worker runs periodically to fetch JWKS (JSON Web Key Sets) from LTI platform
  providers and cache them in ETS. By fetching keys out-of-band (not during launch),
  we eliminate HTTP failures during student launches and follow the LTI 1.3 spec
  recommendation.

  Features:
  - Respects cache-control headers from platform providers
  - Automatic retry on HTTP failures via Oban
  - Graceful error handling and logging
  - Can process individual registrations or all active ones
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 5

  require Logger
  alias Oli.Lti.KeysetCache
  alias Oli.Repo

  @default_ttl_seconds 3600
  @http_timeout_ms 10_000

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"registration_id" => registration_id}}) do
    registration_id
    |> get_registration()
    |> fetch_and_cache_keyset()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"refresh_all" => true}}) do
    Logger.info("Refreshing keysets for all active LTI registrations")

    results =
      list_all_registrations()
      |> Enum.map(fn registration ->
        case fetch_and_cache_keyset(registration) do
          :ok ->
            {:ok, registration.id}

          {:error, reason} ->
            Logger.warning(
              "Failed to refresh keyset for registration #{registration.id}: #{inspect(reason)}"
            )

            {:error, registration.id, reason}
        end
      end)

    successful = Enum.count(results, &match?({:ok, _}, &1))
    failed = Enum.count(results, &match?({:error, _, _}, &1))

    Logger.info(
      "Keyset refresh completed: #{successful} successful, #{failed} failed out of #{length(results)} total"
    )

    :ok
  end

  @doc """
  Schedules a keyset refresh job for a specific registration.
  """
  def schedule_refresh(registration_id) do
    %{registration_id: registration_id}
    |> new()
    |> Oban.insert()
  end

  @doc """
  Schedules a keyset refresh job for all active registrations.
  """
  def schedule_refresh_all do
    %{refresh_all: true}
    |> new()
    |> Oban.insert()
  end

  # Private Functions

  defp get_registration(registration_id) do
    Repo.get(Oli.Lti.Tool.Registration, registration_id)
  end

  defp list_all_registrations do
    import Ecto.Query

    Oli.Lti.Tool.Registration
    |> where([r], not is_nil(r.key_set_url))
    |> Repo.all()
  end

  defp fetch_and_cache_keyset(nil) do
    # Discard job - registration doesn't exist (permanent failure)
    :discard
  end

  defp fetch_and_cache_keyset(%{key_set_url: nil} = registration) do
    Logger.warning(
      "Registration #{registration.id} has no key_set_url configured, skipping keyset refresh"
    )

    # Discard job - missing key_set_url is a permanent configuration issue
    :discard
  end

  defp fetch_and_cache_keyset(%{key_set_url: key_set_url, id: registration_id} = _registration) do
    Logger.debug("Fetching keyset from #{key_set_url} for registration #{registration_id}")

    with :ok <- validate_https_url(key_set_url),
         {:ok, response} <- http_get(key_set_url) do
      handle_http_response(response, key_set_url)
    else
      # URL validation failures are permanent configuration errors - discard immediately
      {:error, :invalid_url_no_scheme} -> :discard
      {:error, :insecure_url_scheme} -> :discard
      {:error, :invalid_url_no_host} -> :discard
      # HTTP/network errors may be transient - allow retry
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_http_response(%{status_code: 200, body: body, headers: headers}, key_set_url) do
    case Jason.decode(body) do
      {:ok, %{"keys" => keys}} when is_list(keys) ->
        ttl = parse_cache_control_max_age(headers)

        Logger.info(
          "Successfully fetched #{length(keys)} keys from #{key_set_url}, caching with TTL #{ttl}s"
        )

        KeysetCache.put_keyset(key_set_url, keys, ttl)
        :ok

      {:ok, invalid_json} ->
        Logger.error(
          "Invalid JWKS format from #{key_set_url}: missing 'keys' array. Body: #{inspect(invalid_json)}"
        )

        # Platform is returning invalid JWKS - permanent config issue, discard
        :discard

      {:error, decode_error} ->
        Logger.error("Failed to decode JSON from #{key_set_url}: #{inspect(decode_error)}")
        # Platform is returning invalid JSON - permanent config issue, discard
        :discard
    end
  end

  defp handle_http_response(%{status_code: status_code}, key_set_url)
       when status_code in 400..499 do
    Logger.error(
      "HTTP #{status_code} client error fetching keyset from #{key_set_url} - permanent failure"
    )

    # 4xx errors are permanent (wrong URL, unauthorized, not found) - discard
    :discard
  end

  defp handle_http_response(%{status_code: status_code}, key_set_url) do
    Logger.error("HTTP #{status_code} error fetching keyset from #{key_set_url}")
    # 5xx errors and other codes may be transient - allow retry
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
        # Parse "max-age=3600" from cache-control header
        case Regex.run(~r/max-age=(\d+)/, cache_control) do
          [_, max_age_str] ->
            String.to_integer(max_age_str)

          _ ->
            @default_ttl_seconds
        end
    end
  end
end
