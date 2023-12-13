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

  @cache_name :cache_section

  @cache_keys [
    :ordered_container_labels
  ]

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
    case get("#{section_slug}_#{key}") do
      {:ok, nil} ->
        Logger.info(
          "Section #{section_slug} has no cached entry for #{section_slug}_#{key}. One will be computed now and cached."
        )

        value = fun.()

        put(key, value)

        value

      {:ok, value} ->
        value
    end
  end

  def clear(section_slug) do
    for key <- @cache_keys do
      delete("#{section_slug}_#{key}")
    end
  end

  # ----------------
  # Server callbacks

  def init(_) do
    {:ok, _pid} = Cachex.start_link(@cache_name, stats: true)

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
    ttl = :timer.hours(24 * 365)

    case Cachex.put(@cache_name, key, value, ttl: ttl) do
      {:ok, true} ->
        {:reply, :ok, state}

      _ ->
        {:reply, :error, state}
    end
  end
end
