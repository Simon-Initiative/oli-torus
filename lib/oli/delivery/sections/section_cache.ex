defmodule Oli.Delivery.Sections.SectionCache do
  @moduledoc """
    Provides a cache that can be used for section delivery related information retrieval. This cache is backed by
    Cachex for local storage.

    Keys are set to expire after 1 year as that is the longest a section is expected to be active.
    This is to prevent data from building up in the cache over a long time period. It is more than
    likely that the cache will be restarted/cleared before the 1 year expiration.
  """

  use GenServer

  require Logger

  @dispatcher Application.compile_env(:oli, [:section_cache, :dispatcher], Phoenix.PubSub)
  @cache_name :cache_section

  @cache_keys [
    :ordered_container_labels,
    :contained_scheduling_types,
    :page_to_container_map,
    :full_hierarchy,
    :section_prompt_info
  ]

  @broadcastable_cache_keys [
    :ordered_container_labels,
    :full_hierarchy
  ]

  @ttl :timer.hours(24 * 365)

  # ----------------
  # Client

  def start_link(init_args),
    do: GenServer.start_link(__MODULE__, init_args, name: __MODULE__)

  def get(key),
    do: GenServer.call(__MODULE__, {:get, key})

  def delete(key),
    do: GenServer.call(__MODULE__, {:delete, key})

  def put(key, value),
    do: GenServer.call(__MODULE__, {:put, key, value})

  @doc """
    Retrieves a cached value for a specific section and key combination. If the value is not already cached,
    it computes the value using the provided function, caches it, and then returns it. This function also
    checks if the key is broadcastable and, if so, broadcasts the cache update.

    ## Examples

        iex> Oli.Delivery.Sections.SectionCache.get_or_compute("my_section", "my_key", fn -> "computed_value" end)
        "computed_value"

  """
  def get_or_compute(section_slug, key, fun) when key in @cache_keys do
    cache_id = cache_id(section_slug, key)

    case get(cache_id) do
      {:ok, nil} ->
        Logger.info(
          "Section #{section_slug} has no cached entry for #{cache_id}. One will be computed now and cached."
        )

        value = fun.()

        put(cache_id, value)

        maybe_broadcast({:put, key, value}, section_slug)

        value

      {:ok, value} ->
        value
    end
  end

  @doc """
    Clears all cached data related to a specific section. This function iterates over an optional list of cache keys (defaults to @cache_keys),
    clears each one associated with the given section slug, and broadcasts the deletion if the key is broadcastable.
    It is useful for ensuring the cache does not hold outdated data for a section.
    If a provided key is not in the list of cache keys, an error tuple is returned.

    ## Examples

        iex> Oli.Delivery.Sections.SectionCache.clear("my_section")
        :ok

        iex> Oli.Delivery.Sections.SectionCache.clear("my_section", [:ordered_container_labels])
        :ok

        iex> Oli.Delivery.Sections.SectionCache.clear("my_section", [:invented_key])
        {:error, :not_existing_cache_key}

  """
  def clear(section_slug, keys \\ @cache_keys) do
    if MapSet.subset?(MapSet.new(keys), MapSet.new(@cache_keys)) do
      for key <- keys do
        Logger.info("Clearing #{key} from cache for section #{section_slug}.")

        delete(cache_id(section_slug, key))

        maybe_broadcast({:delete, key}, section_slug)
      end
    else
      {:error, :not_existing_cache_key}
    end
  end

  def cache_topic, do: Atom.to_string(@cache_name)

  def cache_keys, do: @cache_keys

  def broadcastable_cache_keys, do: @broadcastable_cache_keys

  # ----------------
  # Server callbacks

  def init(_) do
    {:ok, _pid} = Cachex.start_link(@cache_name, stats: true)
    Phoenix.PubSub.subscribe(Oli.PubSub, cache_topic())

    {:ok, []}
  end

  def handle_call({:get, key}, _from, state) do
    {:reply, Cachex.get(@cache_name, key), state}
  end

  def handle_call({:delete, key}, _from, state) do
    case Cachex.del(@cache_name, key) do
      {:ok, true} ->
        {:reply, :ok, state}

      _ ->
        {:reply, :error, state}
    end
  end

  def handle_call({:put, key, value}, _from, state) do
    case Cachex.put(@cache_name, key, value, ttl: @ttl) do
      {:ok, true} ->
        {:reply, :ok, state}

      _ ->
        {:reply, :error, state}
    end
  end

  # ----------------
  # PubSub/Messages callbacks

  def handle_info({:delete, key}, state) do
    Cachex.del(@cache_name, key)

    {:noreply, state}
  end

  def handle_info({:put, key, value}, state) do
    Cachex.put(@cache_name, key, value, ttl: @ttl)

    {:noreply, state}
  end

  # ----------------
  # Private

  defp cache_id(section_slug, key), do: "#{section_slug}_#{key}"

  defp maybe_broadcast({:put, key, hierarchy}, section_slug)
       when key in @broadcastable_cache_keys,
       do: broadcast_message({:put, cache_id(section_slug, key), hierarchy})

  defp maybe_broadcast({:delete, key}, section_slug) when key in @broadcastable_cache_keys,
    do: broadcast_message({:delete, cache_id(section_slug, key)})

  defp maybe_broadcast(_, _), do: nil

  defp broadcast_message(message) do
    Phoenix.PubSub.broadcast_from(
      Oli.PubSub,
      self(),
      cache_topic(),
      message,
      @dispatcher
    )
  end
end
