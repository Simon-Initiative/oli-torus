defmodule Oli.GenAI.Breaker do
  @moduledoc """
  Per-model circuit breaker that tracks rolling health and exposes state snapshots.
  """

  use GenServer

  require Logger

  alias Oli.GenAI.AdmissionControl
  alias Oli.GenAI.Telemetry

  @window_size 50

  @doc "Starts a breaker process for the given RegisteredModel id."
  def start_link(registered_model_id) do
    GenServer.start_link(__MODULE__, registered_model_id, name: via(registered_model_id))
  end

  @doc "Reports an outcome to update breaker health and state."
  def report(registered_model_id, report) do
    ensure_started(registered_model_id)
    GenServer.cast(via(registered_model_id), {:report, report})
  end

  @doc "Returns the current breaker state."
  def status(registered_model_id) do
    ensure_started(registered_model_id)
    GenServer.call(via(registered_model_id), :status)
  end

  @doc "Returns the latest breaker snapshot from ETS."
  def snapshot(registered_model_id) do
    AdmissionControl.get_breaker_snapshot(registered_model_id)
  end

  defp ensure_started(registered_model_id) do
    case Registry.lookup(Oli.GenAI.BreakerRegistry, registered_model_id) do
      [{_pid, _}] -> :ok
      [] -> Oli.GenAI.BreakerSupervisor.start_breaker(registered_model_id)
    end
  end

  defp via(registered_model_id) do
    {:via, Registry, {Oli.GenAI.BreakerRegistry, registered_model_id}}
  end

  @impl true
  @doc "GenServer init callback."
  def init(registered_model_id) do
    state = %{
      registered_model_id: registered_model_id,
      breaker_state: :closed,
      open_until_ms: nil,
      half_open_remaining: 0,
      window: [],
      error_count: 0,
      rate_limit_count: 0,
      latencies_sorted: [],
      last_reason: :ok
    }

    publish_snapshot(state, 0, 0, 0)
    {:ok, state}
  end

  @impl true
  @doc "Handles status requests and updates ETS snapshots."
  def handle_call(:status, _from, state) do
    now_ms = System.monotonic_time(:millisecond)
    state = maybe_transition_from_open(state, now_ms)
    metrics = metrics_from_state(state)
    publish_snapshot(state, metrics.error_rate, metrics.rate_limit_rate, metrics.latency_p95_ms)
    {:reply, state, state}
  end

  @impl true
  @doc "Handles health reports and breaker state transitions."
  def handle_cast({:report, report}, state) do
    now_ms = report_now(report)
    state = maybe_transition_from_open(state, now_ms)

    {state, metrics} =
      case state.breaker_state do
        :open ->
          {state, metrics_from_state(state)}

        :half_open ->
          handle_half_open(report, state, now_ms)

        :closed ->
          handle_closed(report, state, now_ms)
      end

    publish_snapshot(state, metrics.error_rate, metrics.rate_limit_rate, metrics.latency_p95_ms)
    {:noreply, state}
  end

  defp handle_closed(report, state, now_ms) do
    {state, metrics} = add_entry(state, report_entry(report))
    thresholds = report_thresholds(report)

    if should_open?(metrics, thresholds) do
      {open_state(state, thresholds, now_ms, :threshold_exceeded),
       metrics_from_state(reset_window(state))}
    else
      {%{state | last_reason: :ok}, metrics}
    end
  end

  defp handle_half_open(report, state, now_ms) do
    thresholds = report_thresholds(report)
    entry = report_entry(report)

    if entry.error? or entry.rate_limited? or latency_spike?(entry.latency_ms, thresholds) do
      {open_state(state, thresholds, now_ms, :probe_failed),
       metrics_from_state(reset_window(state))}
    else
      remaining = max(state.half_open_remaining - 1, 0)

      if remaining == 0 do
        Telemetry.breaker_state_change(
          %{count: 1},
          %{
            registered_model_id: state.registered_model_id,
            state: :closed,
            reason: :probe_succeeded
          }
        )

        {%{
           state
           | breaker_state: :closed,
             half_open_remaining: 0,
             window: [],
             error_count: 0,
             rate_limit_count: 0,
             latencies_sorted: [],
             last_reason: :probe_succeeded
         }, metrics_from_state(reset_window(state))}
      else
        {%{state | half_open_remaining: remaining, last_reason: :probe_succeeded},
         metrics_from_state(reset_window(state))}
      end
    end
  end

  defp open_state(state, thresholds, now_ms, reason) do
    open_until_ms = now_ms + thresholds.open_cooldown_ms

    Logger.info(
      "Opening GenAI breaker for #{state.registered_model_id} reason=#{inspect(reason)}"
    )

    Telemetry.breaker_state_change(
      %{count: 1},
      %{registered_model_id: state.registered_model_id, state: :open, reason: reason}
    )

    %{
      state
      | breaker_state: :open,
        open_until_ms: open_until_ms,
        half_open_remaining: thresholds.half_open_probe_count,
        window: [],
        error_count: 0,
        rate_limit_count: 0,
        latencies_sorted: [],
        last_reason: reason
    }
  end

  defp maybe_transition_from_open(state, now_ms) do
    if state.breaker_state == :open and not is_nil(state.open_until_ms) and
         now_ms >= state.open_until_ms do
      Logger.info("Transitioning GenAI breaker #{state.registered_model_id} to half_open")

      Telemetry.breaker_state_change(
        %{count: 1},
        %{
          registered_model_id: state.registered_model_id,
          state: :half_open,
          reason: :cooldown_elapsed
        }
      )

      %{
        state
        | breaker_state: :half_open,
          open_until_ms: nil,
          window: [],
          error_count: 0,
          rate_limit_count: 0,
          latencies_sorted: []
      }
    else
      state
    end
  end

  defp report_now(report), do: Map.get(report, :now_ms, System.monotonic_time(:millisecond))

  defp report_thresholds(report) do
    %{
      error_rate_threshold: report.thresholds.error_rate_threshold,
      rate_limit_threshold: report.thresholds.rate_limit_threshold,
      latency_p95_ms: report.thresholds.latency_p95_ms,
      open_cooldown_ms: report.thresholds.open_cooldown_ms,
      half_open_probe_count: report.thresholds.half_open_probe_count
    }
  end

  defp report_entry(report) do
    %{
      error?: report.outcome == :error,
      rate_limited?: report.http_status == 429,
      latency_ms: report.latency_ms || 0
    }
  end

  defp add_entry(state, entry) do
    state = append_entry(state, entry)
    {state, metrics_from_state(state)}
  end

  defp append_entry(state, entry) do
    window = List.insert_at(state.window, -1, entry)
    error_count = state.error_count + if(entry.error?, do: 1, else: 0)
    rate_limit_count = state.rate_limit_count + if(entry.rate_limited?, do: 1, else: 0)
    latencies_sorted = insert_sorted(state.latencies_sorted, entry.latency_ms)

    if length(window) > @window_size do
      [oldest | rest] = window
      error_count = error_count - if(oldest.error?, do: 1, else: 0)
      rate_limit_count = rate_limit_count - if(oldest.rate_limited?, do: 1, else: 0)
      latencies_sorted = remove_sorted(latencies_sorted, oldest.latency_ms)

      %{
        state
        | window: rest,
          error_count: error_count,
          rate_limit_count: rate_limit_count,
          latencies_sorted: latencies_sorted
      }
    else
      %{
        state
        | window: window,
          error_count: error_count,
          rate_limit_count: rate_limit_count,
          latencies_sorted: latencies_sorted
      }
    end
  end

  defp metrics_from_state(%{window: []}) do
    %{error_rate: 0.0, rate_limit_rate: 0.0, latency_p95_ms: 0}
  end

  defp metrics_from_state(state) do
    total = length(state.window)

    %{
      error_rate: state.error_count / total,
      rate_limit_rate: state.rate_limit_count / total,
      latency_p95_ms: percentile_from_sorted(state.latencies_sorted, 95)
    }
  end

  defp percentile_from_sorted([], _), do: 0

  defp percentile_from_sorted(values, p) do
    idx = Float.ceil(length(values) * p / 100) |> trunc()
    Enum.at(values, max(idx - 1, 0)) || 0
  end

  defp insert_sorted([], value), do: [value]

  defp insert_sorted([head | tail] = list, value) do
    if value <= head do
      [value | list]
    else
      [head | insert_sorted(tail, value)]
    end
  end

  defp remove_sorted([], _value), do: []

  defp remove_sorted([head | tail], value) when head == value, do: tail

  defp remove_sorted([head | tail], value), do: [head | remove_sorted(tail, value)]

  defp reset_window(state) do
    %{state | window: [], error_count: 0, rate_limit_count: 0, latencies_sorted: []}
  end

  defp latency_spike?(latency_ms, thresholds) do
    thresholds.latency_p95_ms > 0 and latency_ms >= thresholds.latency_p95_ms
  end

  defp should_open?(metrics, thresholds) do
    metrics.error_rate >= thresholds.error_rate_threshold or
      metrics.rate_limit_rate >= thresholds.rate_limit_threshold or
      (thresholds.latency_p95_ms > 0 and metrics.latency_p95_ms >= thresholds.latency_p95_ms)
  end

  defp publish_snapshot(state, error_rate, rate_limit_rate, latency_p95_ms) do
    AdmissionControl.put_breaker_snapshot(state.registered_model_id, %{
      state: state.breaker_state,
      error_rate: error_rate,
      rate_limit_rate: rate_limit_rate,
      latency_p95_ms: latency_p95_ms,
      half_open_remaining: state.half_open_remaining,
      last_reason: state.last_reason,
      updated_at_ms: System.monotonic_time(:millisecond)
    })
  end
end
