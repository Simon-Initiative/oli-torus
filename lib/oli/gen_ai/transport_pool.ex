defmodule Oli.GenAI.TransportPool do
  @moduledoc """
  Owns one logical pool's replaceable Hackney generations.

  Only already-checked-out references leave the startup fence. Connection workers
  keep coordinators responsive while checkout/connect timeouts run. Short-lived
  startup records exist only to reply, cancel and fence retirement; they never
  decide admission or represent occupied capacity, and are forgotten at handoff.
  Stream lifetime and checked-out occupancy belong exclusively to Hackney.
  """
  use GenServer
  alias Oli.GenAI.Provider

  @doc "Starts a logical pool and adopts surviving generations for retirement."
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @doc "Publishes a fresh generation when its transport configuration changes."
  def configure(pool, spec), do: GenServer.call(pool, {:configure, spec}, 15_000)

  @doc "Rejects new checkouts while allowing already-started work to drain."
  def retire(pool), do: GenServer.call(pool, :retire, 15_000)

  @doc "Reports actual occupancy and configured capacity for every generation."
  def snapshot(pool), do: GenServer.call(pool, :snapshot, 15_000)

  @doc """
  Checks out and transfers a single-use connection reference to the caller.

  Checkout and connection timeouts are distinct. A coordinator timer also bounds
  the full startup budget, including scheduling, without blocking other callers.
  Send exactly one request on the returned reference and close it on every exit.
  An optional monotonic `:deadline` clips the full startup budget. Managed callers
  supply `:expected_signature` so changed credentials/model/endpoint fail locally
  instead of starting with stale execution inputs in a replacement generation.
  """
  def connect(pool, url, opts \\ []) do
    connect_timeout = Keyword.get(opts, :connect_timeout, 8_000)
    checkout_timeout = Keyword.get(opts, :checkout_timeout, 1_000)

    case is_integer(connect_timeout) and connect_timeout > 0 and is_integer(checkout_timeout) and
           checkout_timeout > 0 do
      true ->
        deadline =
          min(
            now() + connect_timeout + checkout_timeout,
            Keyword.get(opts, :deadline, now() + connect_timeout + checkout_timeout)
          )

        token = make_ref()

        result =
          try do
            GenServer.call(pool, {:connect, token, url, opts, deadline}, :infinity)
          catch
            :exit, _ -> {:error, :pool_unavailable}
          end

        case result do
          {:handoff, ref, worker} ->
            send(worker, {:claimed, token})
            {:ok, ref}

          error ->
            error
        end

      false ->
        {:error, :invalid_options}
    end
  catch
    :exit, _ -> {:error, :pool_unavailable}
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)
    key = Keyword.fetch!(opts, :key)

    retired =
      for {{:genai_transport, ^key, _} = name, _pid} <- :ets.tab2list(:hackney_pool), do: name

    state = %{
      key: key,
      current: nil,
      spec: nil,
      retired: retired,
      poll_ms: Keyword.get(opts, :poll_ms, 1_000),
      starts: %{},
      monitors: %{}
    }

    schedule(state)
    {:ok, state}
  end

  @impl true
  def handle_call({:configure, spec}, _from, %{spec: spec, current: current} = state)
      when not is_nil(current), do: {:reply, :ok, state}

  def handle_call({:configure, spec}, _from, state) do
    name = {:genai_transport, state.key, make_ref()}

    case :hackney_pool.start_pool(name, max_connections: spec.capacity) do
      :ok ->
        retired =
          case state.current do
            nil -> state.retired
            old -> [old | state.retired]
          end

        emit(:replaced, state.key)
        {:reply, :ok, %{state | current: name, spec: spec, retired: retired}}

      _ ->
        emit(:creation_failed, state.key)
        {:reply, {:error, :pool_creation_failed}, state}
    end
  end

  def handle_call(:retire, _from, state) do
    retired =
      case state.current do
        nil -> state.retired
        name -> [name | state.retired]
      end

    {:reply, :ok, %{state | current: nil, spec: nil, retired: retired}}
  end

  def handle_call(:snapshot, _from, state) do
    {:reply, %{current: stats(state.current), retired: Enum.map(state.retired, &stats/1)}, state}
  end

  def handle_call({:connect, token, url, opts, deadline}, {owner, _} = from, state) do
    case {state.current, state.spec, Provider.origin(url), now() < deadline,
          Keyword.get(opts, :expected_signature, state.spec && Map.get(state.spec, :signature)) ==
            (state.spec && Map.get(state.spec, :signature))} do
      {nil, _, _, _, _} ->
        {:reply, {:error, :pool_unavailable}, state}

      {_, _, _, false, _} ->
        {:reply, {:error, :busy}, state}

      {_, _, _, _, false} ->
        {:reply, {:error, :stale_configuration}, state}

      {name, %{origin: origin}, {:ok, origin}, true, true} ->
        parent = self()

        {pid, worker_ref} =
          spawn_monitor(fn ->
            Process.link(parent)
            start_connection(parent, token, name, url, opts, deadline)
          end)

        owner_ref = Process.monitor(owner)
        timer = Process.send_after(self(), {:startup_timeout, token}, max(deadline - now(), 0))

        startup = %{
          pid: pid,
          pool_key: state.key,
          worker_ref: worker_ref,
          owner_ref: owner_ref,
          owner: owner,
          from: from,
          name: name,
          deadline: deadline,
          timer: timer,
          ref: nil,
          cancelled: false,
          started: now()
        }

        monitors = state.monitors |> Map.put(worker_ref, token) |> Map.put(owner_ref, token)
        {:noreply, %{state | starts: Map.put(state.starts, token, startup), monitors: monitors}}

      _ ->
        {:reply, {:error, :invalid_origin}, state}
    end
  end

  @impl true
  def handle_info({:connection_ready, token, ref}, state) do
    case state.starts[token] do
      %{cancelled: false} = startup ->
        send(startup.pid, {:handoff, startup.owner})
        {:noreply, put_in(state.starts[token].ref, ref)}

      _ ->
        :hackney.close(ref)
        {:noreply, state}
    end
  end

  def handle_info({:connection_result, token, result}, state) do
    case state.starts[token] do
      nil ->
        {:noreply, state}

      %{cancelled: true} ->
        {:noreply, state}

      startup ->
        cause =
          case result do
            {:error, :checkout_timeout} -> :checkout_timeout
            {:ok, _} -> :ok
            _ -> :transport_error
          end

        cause =
          cond do
            now() >= startup.deadline -> :startup_deadline
            not Process.alive?(startup.owner) -> :owner_cancelled
            true -> cause
          end

        result =
          case now() < startup.deadline and Process.alive?(startup.owner) do
            true ->
              normalize(result)

            false ->
              close(startup.ref)
              {:error, :busy}
          end

        reply =
          case result do
            {:ok, ref} -> {:handoff, ref, startup.pid}
            error -> error
          end

        GenServer.reply(startup.from, reply)
        emit_checkout(startup, result, cause)
        {:noreply, forget(state, token)}
    end
  end

  def handle_info({:startup_timeout, token}, state),
    do: {:noreply, cancel(state, token, :startup_deadline)}

  def handle_info({:DOWN, ref, :process, _, _}, state) do
    case state.monitors[ref] do
      nil ->
        {:noreply, state}

      token ->
        startup = state.starts[token]

        case startup.owner_ref == ref do
          true ->
            {:noreply, cancel(state, token, :owner_cancelled)}

          false ->
            close(startup.ref)

            case startup.cancelled do
              true ->
                :ok

              false ->
                GenServer.reply(startup.from, {:error, :pool_unavailable})
                emit_checkout(startup, {:error, :pool_unavailable}, :worker_exit)
            end

            {:noreply, forget(state, token)}
        end
    end
  end

  def handle_info(:collect, state) do
    retired =
      Enum.reject(state.retired, fn name ->
        starting = Enum.any?(state.starts, fn {_, startup} -> startup.name == name end)

        case {starting, stats(name)} do
          {false, %{checked_out: 0, queue_depth: 0}} ->
            case :hackney_pool.stop_pool(name) do
              :ok ->
                emit(:retired, state.key)
                true

              _ ->
                emit(:retirement_failed, state.key)
                false
            end

          {_, %{error: _}} ->
            emit(:stats_failed, state.key)
            false

          _ ->
            false
        end
      end)

    schedule(state)
    {:noreply, %{state | retired: retired}}
  end

  def handle_info({:EXIT, _, _}, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state) do
    Enum.each(state.starts, fn {_, startup} ->
      close(startup.ref)
      Process.exit(startup.pid, :kill)
    end)

    # Native pools remain under hackney_sup. A replacement coordinator adopts
    # them, preserving occupancy of connections already handed to callers.
    :ok
  end

  defp start_connection(parent, token, name, url, opts, deadline) do
    options =
      opts
      |> Keyword.drop([:deadline, :expected_signature])
      |> Keyword.put(:pool, name)
      |> Keyword.put(
        :checkout_timeout,
        min(Keyword.get(opts, :checkout_timeout, 1_000), max(deadline - now(), 1))
      )
      |> Keyword.put(
        :connect_timeout,
        min(Keyword.get(opts, :connect_timeout, 8_000), max(deadline - now(), 1))
      )
      |> Keyword.put(:follow_redirect, false)

    case :hackney.connect(url, options) do
      {:ok, ref} ->
        send(parent, {:connection_ready, token, ref})

        receive do
          {:handoff, owner} ->
            # Keep a guardian only until the caller acknowledges the reference.
            # If the coordinator dies between ownership transfer and reply, an
            # unclaimed checkout is closed even when its caller remains alive.
            Process.flag(:trap_exit, true)
            owner_ref = Process.monitor(owner)

            result =
              case :hackney.controlling_process(ref, owner) do
                :ok ->
                  Process.delete(ref)
                  {:ok, ref}

                _ ->
                  :hackney.close(ref)
                  {:error, :pool_unavailable}
              end

            send(parent, {:connection_result, token, result})

            case result do
              {:ok, ref} -> await_claim(parent, owner_ref, token, ref, deadline)
              _ -> :ok
            end

            Process.demonitor(owner_ref, [:flush])
        after
          max(deadline - now(), 0) -> :hackney.close(ref)
        end

      error ->
        send(parent, {:connection_result, token, error})
    end
  end

  defp await_claim(parent, owner_ref, token, ref, deadline) do
    receive do
      {:claimed, ^token} ->
        :ok

      {:DOWN, ^owner_ref, :process, _, _} ->
        close(ref)

      {:EXIT, ^parent, _} ->
        receive do
          {:claimed, ^token} -> :ok
        after
          0 -> close(ref)
        end
    after
      max(deadline - now(), 0) -> close(ref)
    end
  end

  defp cancel(state, token, cause) do
    case state.starts[token] do
      nil ->
        state

      %{cancelled: true} ->
        state

      startup ->
        # Retain the startup fence until the worker's DOWN arrives. It cannot
        # recreate a retired pool between cancellation and actual termination.
        close(startup.ref)
        Process.exit(startup.pid, :kill)
        Process.cancel_timer(startup.timer)
        GenServer.reply(startup.from, {:error, :busy})
        emit_checkout(startup, {:error, :busy}, cause)
        put_in(state.starts[token].cancelled, true)
    end
  end

  defp forget(state, token) do
    {startup, starts} = Map.pop(state.starts, token)
    Process.cancel_timer(startup.timer)
    Process.demonitor(startup.worker_ref, [:flush])
    Process.demonitor(startup.owner_ref, [:flush])
    monitors = state.monitors |> Map.delete(startup.worker_ref) |> Map.delete(startup.owner_ref)
    %{state | starts: starts, monitors: monitors}
  end

  defp normalize({:error, :checkout_timeout}), do: {:error, :busy}
  defp normalize({:error, :checkout_failure}), do: {:error, :pool_unavailable}
  defp normalize(result), do: result
  defp close(nil), do: :ok
  defp close(ref), do: :hackney.close(ref)
  defp now, do: System.monotonic_time(:millisecond)
  defp stats(nil), do: nil

  defp stats(name) do
    values = :hackney_pool.get_stats(name)

    %{
      name: name,
      checked_out: values[:in_use_count],
      capacity: values[:max],
      queue_depth: values[:queue_count]
    }
  catch
    :exit, _ -> %{name: name, error: :pool_unavailable}
  end

  defp schedule(state), do: Process.send_after(self(), :collect, state.poll_ms)

  defp emit(event, key),
    do:
      :telemetry.execute([:oli, :genai, :pool, :lifecycle], %{count: 1}, %{
        event: event,
        pool_key: key
      })

  defp emit_checkout(startup, result, cause) do
    outcome =
      case result do
        {:ok, _} -> :ok
        {:error, :busy} -> :busy
        _ -> :error
      end

    elapsed = now() - startup.started
    measurements = %{startup_duration_ms: elapsed}

    measurements =
      case cause do
        :checkout_timeout -> Map.put(measurements, :checkout_timeout_wait_ms, elapsed)
        _ -> measurements
      end

    :telemetry.execute(
      [:oli, :genai, :pool, :checkout],
      measurements,
      %{
        outcome: outcome,
        cause: cause,
        timing_scope: :checkout_and_connect,
        pool_key: startup.pool_key
      }
    )
  end
end
