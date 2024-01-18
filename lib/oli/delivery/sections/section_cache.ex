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

  alias Phoenix.PubSub

  @cache_name :cache_section

  @cache_keys [
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

  def get_or_compute(section_slug, key, fun) do
    cache_id = cache_id(section_slug, key)

    case get(cache_id) do
      {:ok, nil} ->
        Logger.info(
          "Section #{section_slug} has no cached entry for #{section_slug}_#{key}. One will be computed now and cached."
        )

        value = fun.()

        put(cache_id, value)

        maybe_broadcast({:put, key, value}, section_slug)

        value

      {:ok, value} ->
        value
    end
  end

  def clear(section_slug) do
    for key <- @cache_keys do
      Logger.info("Clearing #{key} from cache for section #{section_slug}.")

      delete(cache_id(section_slug, key))

      maybe_broadcast({:delete, key}, section_slug)
    end
  end

  # ----------------
  # Server callbacks

  def init(_) do
    {:ok, _pid} = Cachex.start_link(@cache_name, stats: true)
    PubSub.subscribe(Oli.PubSub, cache_topic())

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

  defp cache_topic,
    do: Atom.to_string(@cache_name)

  defp maybe_broadcast({:put, :full_hierarchy = key, hierarchy}, section_slug),
    do: broadcast_message({:put, cache_id(section_slug, key), hierarchy})

  defp maybe_broadcast({:delete, :full_hierarchy = key}, section_slug),
    do: broadcast_message({:delete, cache_id(section_slug, key)})

  defp maybe_broadcast(_, _), do: nil

  defp broadcast_message(message),
    do:
      PubSub.broadcast_from(
        Oli.PubSub,
        self(),
        cache_topic(),
        message
      )
end
