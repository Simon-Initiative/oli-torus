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
  alias Oli.Lti.KeysetFetcher
  alias Oli.Repo

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

          :discard ->
            :discard

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
    Logger.info("Discarding keyset refresh because registration was not found")

    # Discard job - registration doesn't exist (permanent failure)
    :discard
  end

  defp fetch_and_cache_keyset(%{key_set_url: nil} = registration) do
    Logger.info(
      "Discarding keyset refresh for registration #{registration.id} because key_set_url is not configured"
    )

    Logger.warning(
      "Registration #{registration.id} has no key_set_url configured, skipping keyset refresh"
    )

    # Discard job - missing key_set_url is a permanent configuration issue
    :discard
  end

  defp fetch_and_cache_keyset(%{key_set_url: key_set_url, id: registration_id} = _registration) do
    Logger.debug("Fetching keyset from #{key_set_url} for registration #{registration_id}")

    case KeysetFetcher.fetch_and_cache(key_set_url) do
      {:ok, %{keys: keys, ttl_seconds: ttl_seconds}} ->
        Logger.info(
          "Successfully fetched #{length(keys)} keys from #{key_set_url}, caching with TTL #{ttl_seconds}s"
        )

        :ok

      {:error, :invalid_url_no_scheme} ->
        Logger.info(
          "Discarding keyset refresh for registration #{registration_id}: #{key_set_url} is missing a URL scheme"
        )

        :discard

      {:error, :insecure_url_scheme} ->
        Logger.info(
          "Discarding keyset refresh for registration #{registration_id}: #{key_set_url} uses an insecure URL scheme"
        )

        :discard

      {:error, :invalid_url_no_host} ->
        Logger.info(
          "Discarding keyset refresh for registration #{registration_id}: #{key_set_url} is missing a host"
        )

        :discard

      {:error, {:http_error, status_code}} when status_code in 400..499 ->
        Logger.info(
          "Discarding keyset refresh for registration #{registration_id}: HTTP #{status_code} client error fetching #{key_set_url}"
        )

        Logger.error(
          "HTTP #{status_code} client error fetching keyset from #{key_set_url} - permanent failure"
        )

        :discard

      {:error, :invalid_jwks_format} ->
        Logger.info(
          "Discarding keyset refresh for registration #{registration_id}: invalid JWKS format from #{key_set_url}"
        )

        :discard

      {:error, :json_decode_failed} ->
        Logger.info(
          "Discarding keyset refresh for registration #{registration_id}: JSON decode failed for #{key_set_url}"
        )

        :discard

      {:error, reason} ->
        Logger.info(
          "Retrying keyset refresh for registration #{registration_id}: transient failure fetching #{key_set_url}"
        )

        Logger.error("Failed to fetch keyset from #{key_set_url}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
