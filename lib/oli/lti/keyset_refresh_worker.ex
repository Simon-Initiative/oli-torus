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
    {:error, :registration_not_found}
  end

  defp fetch_and_cache_keyset(%{key_set_url: nil} = registration) do
    Logger.warning(
      "Registration #{registration.id} has no key_set_url configured, skipping keyset refresh"
    )

    {:error, :no_key_set_url}
  end

  defp fetch_and_cache_keyset(%{key_set_url: key_set_url, id: registration_id} = _registration) do
    Logger.debug("Fetching keyset from #{key_set_url} for registration #{registration_id}")

    case http_get(key_set_url) do
      {:ok, %{status_code: 200, body: body, headers: headers}} ->
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

            {:error, :invalid_jwks_format}

          {:error, decode_error} ->
            Logger.error("Failed to decode JSON from #{key_set_url}: #{inspect(decode_error)}")
            {:error, :json_decode_failed}
        end

      {:ok, %{status_code: status_code}} ->
        Logger.error("HTTP #{status_code} error fetching keyset from #{key_set_url}")
        {:error, {:http_error, status_code}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP request failed for #{key_set_url}: #{inspect(reason)}")
        {:error, {:http_request_failed, reason}}

      {:error, reason} ->
        Logger.error("Unexpected error fetching keyset from #{key_set_url}: #{inspect(reason)}")
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
