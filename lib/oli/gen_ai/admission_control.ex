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

  @doc "Increments the active request counter for a ServiceConfig."
  def increment_requests(service_config_id) do
    update_counter({:requests, service_config_id}, 1)
  end

  @doc "Decrements the active request counter for a ServiceConfig."
  def decrement_requests(service_config_id) do
    update_counter({:requests, service_config_id}, -1)
  end

  @doc "Increments the active stream counter for a ServiceConfig."
  def increment_streams(service_config_id) do
    update_counter({:streams, service_config_id}, 1)
  end

  @doc "Decrements the active stream counter for a ServiceConfig."
  def decrement_streams(service_config_id) do
    update_counter({:streams, service_config_id}, -1)
  end

  @doc "Returns active request/stream counters for a ServiceConfig."
  def counts(service_config_id) do
    %{
      requests: get_counter({:requests, service_config_id}),
      streams: get_counter({:streams, service_config_id})
    }
  end

  @doc "Stores the latest breaker snapshot for a RegisteredModel."
  def put_breaker_snapshot(registered_model_id, snapshot) do
    ensure_tables()
    :ets.insert(@breaker_table, {registered_model_id, snapshot})
    :ok
  end

  @doc "Fetches the latest breaker snapshot for a RegisteredModel."
  def get_breaker_snapshot(registered_model_id) do
    ensure_tables()

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
        :ets.new(name, [
          :named_table,
          :public,
          :set,
          {:read_concurrency, true},
          {:write_concurrency, true}
        ])

      _ ->
        :ok
    end
  end

  defp update_counter(key, delta) do
    ensure_tables()
    new_value = :ets.update_counter(@counters_table, key, {2, delta}, {key, 0})

    if new_value < 0 do
      Logger.warning("GenAI counter below zero for #{inspect(key)}; clamping to 0")
      :ets.insert(@counters_table, {key, 0})
      0
    else
      new_value
    end
  end

  defp get_counter(key) do
    ensure_tables()

    case :ets.lookup(@counters_table, key) do
      [{^key, value}] -> value
      _ -> 0
    end
  end
end
