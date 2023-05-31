defmodule Oli.AccountLookupCache do
  @moduledoc """
    Provides a cache that can be used for account lookups. This cache is backed by
    Cachex for local storage and PubSub for remote distribution. Keys are set to expire
    after 1 day in order to prevent stale data in our cache over a long time period.
  """

  use GenServer

  alias Phoenix.PubSub
  alias Oli.Accounts
  alias Oli.Accounts.{Author, User}

  @cache_name :cache_account_lookup

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
  Gets an author from the cache. If the user is not found in the cache, it will be loaded from the database
  """
  def get_author(author_id) do
    case get("author_#{author_id}") do
      {:ok, %Author{}} = response ->
        response

      _ ->
        case Accounts.get_author_with_community_admin_count(author_id) do
          nil ->
            {:error, :not_found}

          author ->
            put("author_#{author_id}", author)

            {:ok, author}
        end
    end
  end

  def get_author!(author_id) do
    case get_author(author_id) do
      {:ok, author} ->
        author

      _ ->
        raise "Author not found"
    end
  end

  @doc """
  Gets a user from the cache. If the user is not found in the cache, it will be loaded from the database.
  User is returned preloaded with roles.
  """
  def get_user(user_id) do
    case get("user_#{user_id}") do
      {:ok, %User{}} = response ->
        response

      _ ->
        case Accounts.get_user_with_roles(user_id) do
          nil ->
            {:error, :not_found}

          user ->
            put("user_#{user_id}", user)

            {:ok, user}
        end
    end
  end

  def get_user!(user_id) do
    case get_user(user_id) do
      {:ok, user} ->
        user

      _ ->
        raise "User not found"
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

  defp cache_topic,
    do: Atom.to_string(@cache_name)
end
