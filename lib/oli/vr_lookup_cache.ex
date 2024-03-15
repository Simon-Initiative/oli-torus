defmodule Oli.VrLookupCache do
  @moduledoc """
    Provides a cache that can be used for vr_user_agent lookups. This cache is backed by
    Cachex for local storage and PubSub for remote distribution. Keys are set to expire
    after 1 day in order to prevent stale data in our cache over a long time period.
  """

  use GenServer
  alias Oli.VrUserAgents
  alias Phoenix.PubSub
  alias Oli.Accounts.Schemas.VrUserAgent

  @cache_name :vr_lookup_cache

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
  Gets a vr_user_agent record from the cache. If the record is not found in the cache, it will be loaded from the database
  """

  def get_vr_user_agent(user_id) do
    case get("vr_user_agent_#{user_id}") do
      {:ok, %VrUserAgent{}} = response ->
        response

      _ ->
        case VrUserAgents.get(user_id) do
          nil ->
            {:error, :not_found}

          vr_user_agent ->
            put("vr_user_agent_#{user_id}", vr_user_agent)

            {:ok, vr_user_agent}
        end
    end
  end

  @spec get_vr_user_agent_value(integer) :: true | false
  def get_vr_user_agent_value(user_id) do
    case get_vr_user_agent(user_id) do
      {:ok, %VrUserAgent{value: value}} -> value
      _ -> false
    end
  end

  # ----------------
  # Server callbacks

  def init(_) do
    {:ok, _pid} = Cachex.start_link(@cache_name, stats: true)
    PubSub.subscribe(Oli.PubSub, cache_topic())

    {:ok, [], {:continue, :init}}
  end

  def handle_continue(:init, state) do
    nodes = Node.list()

    if length(nodes) > 0 do
      # just pick a random node in the cluster to request the dump
      send({__MODULE__, Enum.random(nodes)}, {:request_dump, self()})
    end

    {:noreply, state}
  end

  def handle_call({:get, key}, _from, state) do
    {:reply, Cachex.get(@cache_name, key), state}
  end

  def handle_call({:delete, key}, _from, state) do
    case Cachex.del(@cache_name, key) do
      {:ok, true} ->
        PubSub.broadcast_from(Oli.PubSub, self(), cache_topic(), {:delete, key})
        {:reply, :ok, state}

      _ ->
        {:reply, :error, state}
    end
  end

  def handle_call({:put, key, value}, _from, state) do
    ttl = :timer.hours(24)

    case Cachex.put(@cache_name, key, value, ttl: ttl) do
      {:ok, true} ->
        PubSub.broadcast_from(Oli.PubSub, self(), cache_topic(), {:put, key, value, ttl})
        {:reply, :ok, state}

      _ ->
        {:reply, :error, state}
    end
  end

  # ----------------
  # PubSub/Messages callbacks

  def handle_info({:request_dump, request_pid}, state) do
    Task.start(fn ->
      {:ok, export} = Cachex.export(@cache_name)

      send(request_pid, {:load_dump, export})
    end)

    {:noreply, state}
  end

  def handle_info({:load_dump, export}, state) do
    Cachex.import(@cache_name, export)

    {:noreply, state}
  end

  def handle_info({:delete, key}, state) do
    Cachex.del(@cache_name, key)

    {:noreply, state}
  end

  def handle_info({:put, key, value, ttl}, state) do
    Cachex.put(@cache_name, key, value, ttl: ttl)

    {:noreply, state}
  end

  # ----------------
  # Private

  defp cache_topic, do: Atom.to_string(@cache_name)
end
