defmodule Oli.Lti.KeysetCache do
  @moduledoc """
  GenServer that manages an ETS-based cache for LTI platform public keysets.

  This cache stores JWKS (JSON Web Key Sets) fetched from LTI platform providers
  to avoid fetching them during student launches. Keys are cached with expiration
  times based on HTTP cache-control headers.

  The cache is designed to:
  - Eliminate HTTP calls during launch validation (faster, more reliable)
  - Respect cache-control headers from platform providers
  - Provide better error messages distinguishing HTTP failures from missing keys
  - Support the LTI 1.3 specification's recommendation for out-of-band key fetching
  """

  use GenServer
  require Logger

  @table_name :lti_keyset_cache
  @default_ttl_seconds 3600

  # Client API

  @doc """
  Starts the keyset cache GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets a cached keyset for the given key_set_url.

  Returns `{:ok, keyset_data}` if found and not expired, `{:error, :not_found}` otherwise.

  ## Examples

      iex> get_keyset("https://canvas.instructure.com/api/lti/security/jwks")
      {:ok, %{keys: [...], fetched_at: ~U[...], expires_at: ~U[...]}}
  """
  def get_keyset(key_set_url) do
    case :ets.lookup(@table_name, key_set_url) do
      [{^key_set_url, keyset_data}] ->
        if expired?(keyset_data) do
          # Clean up expired entry via GenServer (respects :protected access)
          delete_keyset(key_set_url)
          {:error, :not_found}
        else
          {:ok, keyset_data}
        end

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Stores a keyset in the cache with an expiration time.

  ## Parameters

    - `key_set_url`: The URL of the JWKS endpoint
    - `keys`: List of parsed JWK keys
    - `ttl_seconds`: Time-to-live in seconds (optional, defaults to 1 hour)

  ## Examples

      iex> put_keyset("https://example.com/jwks", [%{"kid" => "key1", ...}], 3600)
      :ok
  """
  def put_keyset(key_set_url, keys, ttl_seconds \\ @default_ttl_seconds) do
    GenServer.call(__MODULE__, {:put_keyset, key_set_url, keys, ttl_seconds})
  end

  @doc """
  Gets a specific public key by kid (key ID) from the cached keyset.

  Returns `{:ok, public_key}` if found, `{:error, reason}` otherwise.

  ## Examples

      iex> get_public_key("https://canvas.instructure.com/api/lti/security/jwks", "key123")
      {:ok, %JOSE.JWK{}}
  """
  def get_public_key(key_set_url, kid) do
    case get_keyset(key_set_url) do
      {:ok, %{keys: keys}} ->
        case find_key_by_kid(keys, kid) do
          nil ->
            {:error, :key_not_found}

          key ->
            {:ok, JOSE.JWK.from_map(key)}
        end

      {:error, :not_found} ->
        {:error, :keyset_not_cached}
    end
  end

  @doc """
  Deletes a keyset from the cache.

  Useful for forcing a refresh or cleaning up invalid data.
  """
  def delete_keyset(key_set_url) do
    GenServer.call(__MODULE__, {:delete_keyset, key_set_url})
  end

  @doc """
  Returns all cached key_set_urls.

  Useful for debugging and monitoring.
  """
  def list_cached_urls do
    :ets.tab2list(@table_name)
    |> Enum.map(fn {url, _data} -> url end)
  end

  @doc """
  Clears all cached keysets.

  Primarily for testing purposes.
  """
  def clear_cache do
    GenServer.call(__MODULE__, :clear_cache)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS table with protected access
    # :set - each key_set_url is unique
    # :named_table - can reference by name instead of table ID
    # :protected - only owner process can write, all can read
    # {:read_concurrency, true} - optimize for concurrent reads
    table =
      :ets.new(@table_name, [
        :set,
        :named_table,
        :protected,
        {:read_concurrency, true}
      ])

    Logger.info("LTI Keyset Cache initialized with ETS table #{inspect(table)}")

    {:ok, %{}}
  end

  @impl true
  def handle_call({:put_keyset, key_set_url, keys, ttl_seconds}, _from, state) do
    now = DateTime.utc_now()
    expires_at = DateTime.add(now, ttl_seconds, :second)

    keyset_data = %{
      keys: keys,
      fetched_at: now,
      expires_at: expires_at
    }

    :ets.insert(@table_name, {key_set_url, keyset_data})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delete_keyset, key_set_url}, _from, state) do
    :ets.delete(@table_name, key_set_url)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:clear_cache, _from, state) do
    :ets.delete_all_objects(@table_name)
    {:reply, :ok, state}
  end

  # Private Functions

  defp expired?(%{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  defp find_key_by_kid(keys, kid) do
    Enum.find(keys, fn key ->
      Map.get(key, "kid") == kid
    end)
  end
end
