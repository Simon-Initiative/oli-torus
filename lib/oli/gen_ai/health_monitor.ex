defmodule Oli.GenAI.HealthMonitor do
  @moduledoc "Node-local Provider health driven exclusively by independently scheduled probes."
  use GenServer
  alias Oli.GenAI.{HealthProbe, Provider}

  @doc "Starts a responsive coordinator; network work runs under a separate task supervisor."
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @doc "Returns safe administrative, observed-health and scheduling information."
  def snapshot(monitor), do: GenServer.call(monitor, :snapshot)

  @doc "Replaces probe inputs, cancels obsolete work and resets observed evidence."
  def configure(monitor, config), do: GenServer.call(monitor, {:configure, config})

  @doc "Schedules an explicit diagnostic check; ordinary request outcomes never call this API."
  def check(monitor), do: GenServer.cast(monitor, :check)

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    state = %{
      config: Keyword.fetch!(opts, :config),
      task_supervisor: Keyword.fetch!(opts, :task_supervisor),
      probe: Keyword.fetch!(opts, :probe),
      jitter_ms: Keyword.get(opts, :jitter_ms, 5_000),
      task: nil,
      timer: nil,
      generation: make_ref(),
      observed: :unknown,
      failures: 0,
      successes: 0,
      last_check: nil,
      last_success: nil,
      completed_at: nil,
      next_check: nil,
      failure_category: nil
    }

    {:ok, schedule(state, 0)}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    %{provider: provider, model: model, enabled: enabled} = state.config
    policy = Provider.policy(provider)

    stale =
      state.observed == :available and not is_nil(state.completed_at) and
        now() - state.completed_at > 2 * policy.probe_interval_ms + policy.probe_deadline_ms

    observed =
      case stale do
        true -> :stale
        false -> state.observed
      end

    category = HealthProbe.configuration_error(provider, model) || state.failure_category

    eligible =
      provider.enabled and
        (not enabled or
           (is_nil(HealthProbe.configuration_error(provider, model)) and
              observed in [:unknown, :available]))

    snapshot = %{
      provider_id: provider.id,
      administrative_enabled: provider.enabled,
      monitoring_enabled: enabled,
      observed: observed,
      eligible: eligible,
      health_check_model_id: model && model.id,
      last_check: state.last_check,
      last_success: state.last_success,
      next_check: state.next_check,
      consecutive_failures: state.failures,
      consecutive_successes: state.successes,
      failure_category: category,
      probe_in_flight: not is_nil(state.task),
      policy: policy
    }

    {:reply, snapshot, state}
  end

  def handle_call({:configure, config}, _from, %{config: config} = state),
    do: {:reply, :ok, state}

  def handle_call({:configure, config}, _from, state) do
    cancel_timer(state.timer)

    state = %{
      state
      | config: config,
        generation: make_ref(),
        observed: :unknown,
        failures: 0,
        successes: 0,
        last_check: nil,
        last_success: nil,
        completed_at: nil,
        next_check: nil,
        failure_category: nil,
        timer: nil
    }

    state =
      case state.task do
        nil ->
          schedule(state, 0)

        task ->
          Process.exit(task.pid, :kill)
          state
      end

    {:reply, :ok, state}
  end

  @impl true
  def handle_cast(:check, state) do
    cancel_timer(state.timer)
    {:noreply, schedule(%{state | timer: nil}, 0)}
  end

  @impl true
  def handle_info({:check, token}, %{timer: {_timer, token}} = state) do
    state = %{state | timer: nil, next_check: nil}

    case {state.config.enabled and state.config.provider.enabled, state.task,
          HealthProbe.configuration_error(state.config.provider, state.config.model)} do
      {false, _, _} -> {:noreply, state}
      {_, task, _} when not is_nil(task) -> {:noreply, state}
      {true, nil, nil} -> {:noreply, start_probe(state)}
      {true, nil, category} -> {:noreply, %{state | failure_category: category}}
    end
  end

  def handle_info({:probe_result, token, result}, %{task: %{token: token} = task} = state) do
    case task.generation == state.generation do
      true ->
        Process.demonitor(task.ref, [:flush])
        cancel_timer(task.deadline)
        state = %{state | task: nil} |> record_result(result, now() - task.started)
        {:noreply, schedule(state, next_interval(state))}

      false ->
        {:noreply, state}
    end
  end

  def handle_info({:deadline, token}, %{task: %{token: token} = task} = state) do
    Process.exit(task.pid, :kill)
    {:noreply, %{state | task: Map.put(task, :timed_out, true)}}
  end

  def handle_info({:DOWN, ref, :process, _, _}, %{task: %{ref: ref} = task} = state) do
    cancel_timer(task.deadline)
    state = %{state | task: nil}

    case task.generation == state.generation do
      false ->
        {:noreply, schedule(state, 0)}

      true ->
        category =
          case task.timed_out do
            true -> :deadline_exceeded
            false -> :task_exit
          end

        state = record_result(state, {:error, category}, now() - task.started)
        {:noreply, schedule(state, next_interval(state))}
    end
  end

  def handle_info(_, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, %{task: nil}), do: :ok

  def terminate(_reason, %{task: task}) do
    Process.exit(task.pid, :kill)

    receive do
      {:DOWN, ref, :process, _, _} when ref == task.ref -> :ok
    after
      1_000 -> :ok
    end
  end

  defp start_probe(state) do
    parent = self()
    generation = state.generation
    token = make_ref()
    config = state.config
    probe = state.probe

    case Task.Supervisor.start_child(state.task_supervisor, fn ->
           Process.link(parent)

           result =
             try do
               probe.(config.provider, config.model)
             rescue
               _ -> {:error, :probe_exception}
             catch
               _, _ -> {:error, :probe_exception}
             end

           send(parent, {:probe_result, token, result})
         end) do
      {:ok, pid} ->
        ref = Process.monitor(pid)

        deadline =
          Process.send_after(
            self(),
            {:deadline, token},
            Provider.policy(config.provider).probe_deadline_ms
          )

        %{
          state
          | task: %{
              pid: pid,
              ref: ref,
              generation: generation,
              token: token,
              deadline: deadline,
              timed_out: false,
              started: now()
            }
        }

      {:error, _} ->
        :telemetry.execute([:oli, :genai, :health, :monitor_error], %{count: 1}, %{
          provider_id: config.provider.id,
          category: :probe_capacity
        })

        schedule(state, 1_000)
    end
  end

  defp record_result(state, {:local_error, category}, duration) do
    emit(state, :local_error, category, duration)
    %{state | failure_category: category}
  end

  defp record_result(state, {:configuration_error, category}, duration) do
    emit(state, :configuration_error, category, duration)
    %{state | observed: :unknown, failure_category: category}
  end

  defp record_result(state, result, duration) do
    success = result == :ok

    category =
      case result do
        :ok -> nil
        {:error, category} when is_atom(category) -> category
        _ -> :probe_error
      end

    policy = Provider.policy(state.config.provider)

    failures =
      case success do
        true -> 0
        false -> state.failures + 1
      end

    successes =
      case success do
        true -> state.successes + 1
        false -> 0
      end

    observed =
      cond do
        failures >= policy.failure_threshold -> :unavailable
        success and state.observed != :unavailable -> :available
        successes >= policy.recovery_threshold -> :available
        true -> state.observed
      end

    emit(
      state,
      case success do
        true -> :ok
        false -> :error
      end,
      category,
      duration
    )

    case observed != state.observed do
      true ->
        :telemetry.execute([:oli, :genai, :health, :state_change], %{count: 1}, %{
          provider_id: state.config.provider.id,
          state: observed
        })

      false ->
        :ok
    end

    timestamp = DateTime.utc_now()

    %{
      state
      | observed: observed,
        failures: failures,
        successes: successes,
        last_check: timestamp,
        last_success:
          case success do
            true -> timestamp
            false -> state.last_success
          end,
        completed_at: now(),
        failure_category: category
    }
  end

  defp next_interval(state) do
    policy = Provider.policy(state.config.provider)

    case state.observed != :unavailable and state.failures > 0 do
      true -> policy.probe_failure_interval_ms
      false -> policy.probe_interval_ms
    end
  end

  defp schedule(%{config: %{enabled: false}} = state, _delay), do: %{state | next_check: nil}

  defp schedule(%{config: %{provider: %{enabled: false}}} = state, _delay),
    do: %{state | next_check: nil}

  defp schedule(state, delay) do
    jitter =
      case delay > 0 and state.jitter_ms > 0 do
        true -> :rand.uniform(state.jitter_ms)
        false -> 0
      end

    delay = delay + jitter
    token = make_ref()
    timer = Process.send_after(self(), {:check, token}, delay)

    %{
      state
      | timer: {timer, token},
        next_check: DateTime.add(DateTime.utc_now(), delay, :millisecond)
    }
  end

  defp cancel_timer(nil), do: :ok
  defp cancel_timer({timer, _token}), do: Process.cancel_timer(timer)
  defp cancel_timer(timer), do: Process.cancel_timer(timer)
  defp now, do: System.monotonic_time(:millisecond)

  defp emit(state, outcome, category, duration),
    do:
      :telemetry.execute([:oli, :genai, :health, :probe], %{duration_ms: duration}, %{
        provider_id: state.config.provider.id,
        registered_model_id: state.config.model && state.config.model.id,
        outcome: outcome,
        category: category
      })
end
