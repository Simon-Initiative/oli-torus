defmodule Oli.DatashopCache do
  @moduledoc """
    Provides a cache that can be used for datashop export related information retrieval. This cache is backed by
    Cachex for local storage. Keys are set to expire after 1 day in order to prevent stale data in our cache over a long time period.
  """

  use GenServer

  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, ResourceAttempt}
  alias Oli.Resources.Revision
  alias Oli.Repo

  @cache_name :cache_datashop

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
  Gets a revision from the cache. If the revision is not found in the cache, it will be loaded from the database
  """
  def get_revision(revision_id) do
    case get("revision_#{revision_id}") do
      {:ok, %Revision{}} = response ->
        response

      _ ->
        case Repo.get(Revision, revision_id) do
          nil ->
            {:error, :not_found}

          revision ->
            put("revision_#{revision_id}", revision)

            {:ok, revision}
        end
    end
  end

  def get_revision!(revision_id) do
    case get_revision(revision_id) do
      {:ok, revision} ->
        revision

      _ ->
        raise "Revision not found"
    end
  end

  @doc """
  Gets an activity attempt from the cache. If the activity attempt is not found in the cache, it will be loaded from the database
  """
  def get_activity_attempt(activity_attempt_id) do
    case get("activity_attempt_#{activity_attempt_id}") do
      {:ok, %ActivityAttempt{}} = response ->
        response

      _ ->
        case Repo.get(ActivityAttempt, activity_attempt_id) do
          nil ->
            {:error, :not_found}

          activity_attempt ->
            put("activity_attempt_#{activity_attempt_id}", activity_attempt)

            {:ok, activity_attempt}
        end
    end
  end

  def get_activity_attempt!(activity_attempt_id) do
    case get_activity_attempt(activity_attempt_id) do
      {:ok, activity_attempt} ->
        activity_attempt

      _ ->
        raise "Activity attempt not found"
    end
  end

  @doc """
  Gets a resource attempt from the cache. If the resource attempt is not found in the cache, it will be loaded from the database
  """
  def get_resource_attempt(resource_attempt_id) do
    case get("resource_attempt_#{resource_attempt_id}") do
      {:ok, %ResourceAttempt{}} = response ->
        response

      _ ->
        case Repo.get(ResourceAttempt, resource_attempt_id) do
          nil ->
            {:error, :not_found}

          resource_attempt ->
            put("resource_attempt_#{resource_attempt_id}", resource_attempt)

            {:ok, resource_attempt}
        end
    end
  end

  def get_resource_attempt!(resource_attempt_id) do
    case get_resource_attempt(resource_attempt_id) do
      {:ok, resource_attempt} ->
        resource_attempt

      _ ->
        raise "Resource attempt not found"
    end
  end

  # ----------------
  # Server callbacks

  def init(_) do
    {:ok, _pid} = Cachex.start_link(@cache_name, stats: true, limit: cache_limit())

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
    ttl = :timer.hours(24)

    case Cachex.put(@cache_name, key, value, ttl: ttl) do
      {:ok, true} ->
        {:reply, :ok, state}

      _ ->
        {:reply, :error, state}
    end
  end

  # ----------------
  # Private

  defp cache_limit,
    do: Application.fetch_env!(:oli, :datashop)[:cache_limit]
end
