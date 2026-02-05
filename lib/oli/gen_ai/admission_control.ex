defmodule Oli.GenAI.AdmissionControl do
  @moduledoc """
  In-memory admission control counters and breaker snapshots for GenAI routing.

  Uses ETS tables for O(1) reads and updates. All state is per-node and resets
  on process restart.
  """

  use GenServer

  require Logger

  @counters_table :genai_counters
  @breaker_table :genai_breaker_snapshots

  @doc "Starts the admission control process and initializes ETS tables."
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "GenServer init callback; initializes ETS tables."
  def init(_opts) do
    ensure_tables()
    {:ok, %{counters_table: @counters_table, breaker_table: @breaker_table}}
  end

  @doc "Returns the current inflight count for a RegisteredModel."
  def model_count(model_id) do
    get_counter({:inflight, :model, model_id})
  end

  @doc "Increments the inflight counter for a RegisteredModel without enforcing a cap."
  def increment_model(model_id) do
    update_counter({:inflight, :model, model_id}, 1)
  end

  @doc "Returns the current inflight count for a pool."
  def pool_count(pool_name) do
    get_counter({:inflight, :pool, pool_name})
  end

  @doc "Atomically admits a request for a RegisteredModel, enforcing a hard cap."
  def try_admit_model(model_id, hard_limit) do
    try_admit({:inflight, :model, model_id}, hard_limit)
  end

  @doc "Releases an inflight slot for a RegisteredModel."
  def release_model(model_id) do
    update_counter({:inflight, :model, model_id}, -1)
  end

  @doc "Atomically admits a request for a pool, enforcing a hard cap."
  def try_admit_pool(pool_name, hard_limit) do
    try_admit({:inflight, :pool, pool_name}, hard_limit)
  end

  @doc "Releases an inflight slot for a pool."
  def release_pool(pool_name) do
    update_counter({:inflight, :pool, pool_name}, -1)
  end

  @doc "Stores the latest breaker snapshot for a RegisteredModel."
  def put_breaker_snapshot(registered_model_id, snapshot) do
    :ets.insert(@breaker_table, {registered_model_id, snapshot})
    :ok
  end

  @doc "Fetches the latest breaker snapshot for a RegisteredModel."
  def get_breaker_snapshot(registered_model_id) do
    case :ets.lookup(@breaker_table, registered_model_id) do
      [{^registered_model_id, snapshot}] -> snapshot
      _ -> %{state: :closed, half_open_remaining: 0}
    end
  end

  defp ensure_tables do
    create_table(@counters_table)
    create_table(@breaker_table)
  end

  defp create_table(name) do
    case :ets.whereis(name) do
      :undefined ->
        try do
          :ets.new(name, [
            :named_table,
            :public,
            :set,
            {:read_concurrency, true},
            {:write_concurrency, true}
          ])

          :ok
        rescue
          ArgumentError ->
            :ok
        end

      _ ->
        :ok
    end
  end

  defp update_counter(key, delta) do
    new_value = :ets.update_counter(@counters_table, key, {2, delta}, {key, 0})

    if new_value < 0 do
      Logger.warning("GenAI counter below zero for #{inspect(key)}; clamping to 0")
      :ets.insert(@counters_table, {key, 0})
      0
    else
      new_value
    end
  end

  defp try_admit(key, hard_limit) when is_integer(hard_limit) and hard_limit >= 0 do
    new_value = :ets.update_counter(@counters_table, key, {2, 1}, {key, 0})

    if new_value > hard_limit do
      update_counter(key, -1)
      {:error, :over_capacity}
    else
      :ok
    end
  end

  defp try_admit(_key, _hard_limit), do: {:error, :invalid_limit}

  defp get_counter(key) do
    case :ets.lookup(@counters_table, key) do
      [{^key, value}] -> value
      _ -> 0
    end
  end
end
