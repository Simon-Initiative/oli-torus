defmodule Oli.Dashboard.Cache.MissCoalescer do
  @moduledoc """
  Node-local producer/waiter coalescing for identical cache misses.
  """

  use GenServer

  @result_tag :dashboard_cache_coalescer_result

  @type coalesce_key :: term()
  @type wait_ref :: reference()
  @type claim_result :: {:producer, reference()} | {:waiter, wait_ref()}

  @type state :: %{
          inflight: %{
            optional(coalesce_key()) => %{
              producer: pid(),
              monitor_ref: reference(),
              waiters: [{pid(), wait_ref()}]
            }
          },
          monitor_index: %{optional(reference()) => coalesce_key()}
        }

  @doc "Starts miss coalescer process."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  @doc "Claims a key as producer or waiter."
  @spec claim(GenServer.server(), coalesce_key()) :: claim_result()
  def claim(coalescer, key) do
    GenServer.call(coalescer, {:claim, key, self()})
  end

  @doc "Publishes a coalesced result for all waiters."
  @spec publish(GenServer.server(), coalesce_key(), {:ok, term()} | {:error, term()}) :: :ok
  def publish(coalescer, key, result) do
    GenServer.cast(coalescer, {:publish, key, result})
  end

  @doc "Waits for published producer result for a waiter claim ref."
  @spec await(wait_ref(), non_neg_integer()) :: {:ok, term()} | {:error, term()}
  def await(wait_ref, timeout_ms) when is_integer(timeout_ms) and timeout_ms >= 0 do
    receive do
      {@result_tag, ^wait_ref, result} -> result
    after
      timeout_ms -> {:error, :coalescer_timeout}
    end
  end

  @impl true
  def init(_arg) do
    {:ok, %{inflight: %{}, monitor_index: %{}}}
  end

  @impl true
  def handle_call({:claim, key, caller_pid}, _from, state) do
    case Map.get(state.inflight, key) do
      nil ->
        monitor_ref = Process.monitor(caller_pid)
        claim_ref = make_ref()

        inflight_entry = %{producer: caller_pid, monitor_ref: monitor_ref, waiters: []}

        next_state = %{
          state
          | inflight: Map.put(state.inflight, key, inflight_entry),
            monitor_index: Map.put(state.monitor_index, monitor_ref, key)
        }

        {:reply, {:producer, claim_ref}, next_state}

      %{producer: ^caller_pid} ->
        {:reply, {:producer, make_ref()}, state}

      inflight_entry ->
        wait_ref = make_ref()
        waiters = [{caller_pid, wait_ref} | inflight_entry.waiters]
        next_inflight = Map.put(state.inflight, key, %{inflight_entry | waiters: waiters})
        {:reply, {:waiter, wait_ref}, %{state | inflight: next_inflight}}
    end
  end

  @impl true
  def handle_cast({:publish, key, result}, state) do
    case Map.get(state.inflight, key) do
      nil ->
        {:noreply, state}

      %{monitor_ref: monitor_ref, waiters: waiters} ->
        Process.demonitor(monitor_ref, [:flush])

        Enum.each(waiters, fn {pid, wait_ref} ->
          send(pid, {@result_tag, wait_ref, result})
        end)

        next_state = drop_inflight(state, key, monitor_ref)
        {:noreply, next_state}
    end
  end

  @impl true
  def handle_info({:DOWN, monitor_ref, :process, _pid, reason}, state) do
    case Map.get(state.monitor_index, monitor_ref) do
      nil ->
        {:noreply, state}

      key ->
        case Map.get(state.inflight, key) do
          nil ->
            {:noreply, %{state | monitor_index: Map.delete(state.monitor_index, monitor_ref)}}

          %{waiters: waiters} ->
            error = {:error, {:coalescer_producer_down, reason}}

            Enum.each(waiters, fn {pid, wait_ref} ->
              send(pid, {@result_tag, wait_ref, error})
            end)

            next_state = drop_inflight(state, key, monitor_ref)
            {:noreply, next_state}
        end
    end
  end

  defp drop_inflight(state, key, monitor_ref) do
    %{
      state
      | inflight: Map.delete(state.inflight, key),
        monitor_index: Map.delete(state.monitor_index, monitor_ref)
    }
  end
end
