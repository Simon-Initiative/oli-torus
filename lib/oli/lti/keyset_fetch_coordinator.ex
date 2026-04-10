defmodule Oli.Lti.KeysetFetchCoordinator do
  @moduledoc """
  Coalesces concurrent keyset fetches per keyset URL.
  """

  use GenServer

  @default_timeout 12_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def run(key_set_url, fun, timeout \\ @default_timeout) when is_function(fun, 0) do
    case run_with_metadata(key_set_url, fun, timeout) do
      %{result: result} -> result
    end
  end

  def run_with_metadata(key_set_url, fun, timeout \\ @default_timeout) when is_function(fun, 0) do
    case GenServer.call(__MODULE__, {:acquire, key_set_url}, timeout + 1_000) do
      {:owner, token} ->
        result = execute_fetch(fun, timeout)
        GenServer.cast(__MODULE__, {:complete, key_set_url, token, result})
        %{role: :owner, result: result}

      {:waiter, result} ->
        %{role: :waiter, result: result}
    end
  catch
    :exit, {:timeout, _} ->
      %{role: :waiter, result: {:error, :single_flight_timeout}}
  end

  @impl true
  def init(_opts) do
    {:ok, %{entries: %{}}}
  end

  @impl true
  def handle_call({:acquire, key_set_url}, from, %{entries: entries} = state) do
    case Map.get(entries, key_set_url) do
      nil ->
        token = make_ref()
        owner_pid = elem(from, 0)
        monitor_ref = Process.monitor(owner_pid)

        entry = %{
          owner_pid: owner_pid,
          owner_monitor_ref: monitor_ref,
          token: token,
          waiters: []
        }

        {:reply, {:owner, token}, put_in(state, [:entries, key_set_url], entry)}

      entry ->
        updated_entry = %{entry | waiters: [from | entry.waiters]}
        {:noreply, put_in(state, [:entries, key_set_url], updated_entry)}
    end
  end

  @impl true
  def handle_cast({:complete, key_set_url, token, result}, %{entries: entries} = state) do
    case Map.get(entries, key_set_url) do
      %{token: ^token, owner_monitor_ref: monitor_ref, waiters: waiters} ->
        Process.demonitor(monitor_ref, [:flush])
        Enum.each(waiters, &GenServer.reply(&1, {:waiter, result}))
        {:noreply, %{state | entries: Map.delete(entries, key_set_url)}}

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, monitor_ref, :process, _pid, _reason}, %{entries: entries} = state) do
    case Enum.find(entries, fn {_key, entry} -> entry.owner_monitor_ref == monitor_ref end) do
      {key_set_url, %{waiters: waiters}} ->
        Enum.each(waiters, &GenServer.reply(&1, {:waiter, {:error, :single_flight_owner_down}}))
        {:noreply, %{state | entries: Map.delete(entries, key_set_url)}}

      nil ->
        {:noreply, state}
    end
  end

  defp execute_fetch(fun, timeout) do
    task = Task.async(fun)

    try do
      Task.await(task, timeout)
    catch
      :exit, {:timeout, _} ->
        Task.shutdown(task, :brutal_kill)
        {:error, :single_flight_timeout}

      :exit, reason ->
        {:error, {:single_flight_fetch_failed, reason}}
    end
  end
end
