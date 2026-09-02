defmodule Oli.Delivery.Experiments.Telemetry do
  @moduledoc """
  Maps reward-handoff telemetry to low-cardinality AppSignal metrics.

  These metrics make the deferred batch eligibility optimization observable without tagging user,
  section, experiment, or attempt identifiers. Compare eligibility assignment-query volume with
  reward batch size and duration to determine whether query amplification warrants optimization.
  """

  use Supervisor

  @batch_completed_event [:oli, :experiments, :delivery_reward, :batch, :completed]
  @eligibility_completed_event [:oli, :experiments, :delivery_reward, :eligibility, :completed]
  @reward_events [
    [:oli, :experiments, :delivery_reward, :accepted],
    [:oli, :experiments, :delivery_reward, :duplicate],
    [:oli, :experiments, :delivery_reward, :skipped]
  ]

  @doc "Starts the telemetry supervisor and attaches the AppSignal handler."
  def start_link(arg), do: Supervisor.start_link(__MODULE__, arg, name: __MODULE__)

  @impl true
  def init(_arg) do
    :ok = attach_appsignal_handler()
    Supervisor.init([], strategy: :one_for_one)
  end

  @doc "Maps reward batch and eligibility events to AppSignal metrics."
  def handle_event(@batch_completed_event, measurements, metadata, _config) do
    tags = %{status: classify_status(metadata[:status])}

    add_distribution(
      "oli.experiments.reward_handoff.batch.duration_ms",
      measurements,
      :duration_ms,
      tags
    )

    add_distribution(
      "oli.experiments.reward_handoff.batch.attempt_count",
      measurements,
      :attempt_count,
      tags
    )

    add_distribution(
      "oli.experiments.reward_handoff.batch.context_count",
      measurements,
      :context_count,
      tags
    )

    add_distribution(
      "oli.experiments.reward_handoff.batch.failure_count",
      measurements,
      :failure_count,
      tags
    )

    Appsignal.increment_counter("oli.experiments.reward_handoff.batch.completed", 1, tags)
  end

  def handle_event(@eligibility_completed_event, measurements, metadata, _config) do
    tags = %{status: classify_status(metadata[:status])}

    add_distribution(
      "oli.experiments.reward_handoff.eligibility.duration_ms",
      measurements,
      :duration_ms,
      tags
    )

    add_distribution(
      "oli.experiments.reward_handoff.eligibility.assignment_count",
      measurements,
      :assignment_count,
      tags
    )

    Appsignal.increment_counter("oli.experiments.reward_handoff.eligibility.lookup", 1, tags)

    Appsignal.increment_counter(
      "oli.experiments.reward_handoff.eligibility.assignment_query",
      Map.get(measurements, :assignment_query_count, 0),
      tags
    )
  end

  def handle_event(
        [:oli, :experiments, :delivery_reward, outcome],
        _measurements,
        metadata,
        _config
      )
      when outcome in [:accepted, :duplicate, :skipped] do
    tags = %{
      outcome: Atom.to_string(outcome),
      reason: classify_reason(metadata[:reason])
    }

    Appsignal.increment_counter("oli.experiments.reward_handoff.outcome", 1, tags)
  end

  def handle_event(_, _, _, _), do: :ok

  defp add_distribution(metric, measurements, key, tags) do
    Appsignal.add_distribution_value(metric, Map.get(measurements, key, 0), tags)
  end

  defp classify_status(status) when status in [:ok, :error, :matched, :empty],
    do: Atom.to_string(status)

  defp classify_status(_status), do: "unknown"

  defp classify_reason(reason)
       when reason in [
              :attempt_not_found,
              :invalid_normalized_score,
              :invalid_score,
              :missing_assignment,
              :not_first_attempt,
              :pending_attempt,
              :resource_attempt_not_found
            ],
       do: Atom.to_string(reason)

  defp classify_reason({:invalid_lifecycle_state, _state}), do: "invalid_lifecycle_state"
  defp classify_reason(_reason), do: "none"

  defp attach_appsignal_handler do
    case :telemetry.attach_many(
           "experiment-reward-appsignal-handler",
           [@batch_completed_event, @eligibility_completed_event] ++ @reward_events,
           &__MODULE__.handle_event/4,
           %{}
         ) do
      :ok -> :ok
      {:error, :already_exists} -> :ok
    end
  end
end
