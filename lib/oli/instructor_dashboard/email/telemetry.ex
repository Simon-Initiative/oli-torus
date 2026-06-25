defmodule Oli.InstructorDashboard.Email.Telemetry do
  @moduledoc """
  Maps instructor-dashboard email draft telemetry to AppSignal metrics, so AI
  draft generation (a paid external call) is observable in production.

  Metric tags stay low-PII and bounded: `situation_key`, `tone`, and a coarse failure
  `reason`. `section_id` is deliberately NOT a metric tag (effectively unbounded → high
  metric-series cardinality); it remains in the emitted event metadata for log/trace
  correlation. Instructor identity is intentionally NOT tagged here (PII / high cardinality);
  actor-level attribution is a separate follow-up.
  """

  use Supervisor

  @generated_event [:oli, :instructor_dashboard, :email, :draft, :generated]
  @failed_event [:oli, :instructor_dashboard, :email, :draft, :failed]
  @link_stripped_event [:oli, :instructor_dashboard, :email, :draft, :link_stripped]

  @doc "Starts the telemetry supervisor and attaches the AppSignal handler."
  def start_link(arg), do: Supervisor.start_link(__MODULE__, arg, name: __MODULE__)

  @impl true
  def init(_arg) do
    :ok = attach_appsignal_handler()
    Supervisor.init([], strategy: :one_for_one)
  end

  @doc "Telemetry handler that maps email draft events to AppSignal metrics."
  def handle_event(@generated_event, measurements, metadata, _config) do
    tags = base_tags(metadata)

    Appsignal.add_distribution_value(
      "oli.instructor_dashboard.email.draft.duration_ms",
      Map.get(measurements, :duration_ms, 0),
      tags
    )

    Appsignal.increment_counter("oli.instructor_dashboard.email.draft.generated", 1, tags)
  end

  def handle_event(@failed_event, measurements, metadata, _config) do
    tags = Map.put(base_tags(metadata), :reason, normalize(metadata[:reason]))

    Appsignal.add_distribution_value(
      "oli.instructor_dashboard.email.draft.duration_ms",
      Map.get(measurements, :duration_ms, 0),
      tags
    )

    Appsignal.increment_counter("oli.instructor_dashboard.email.draft.failed", 1, tags)
  end

  def handle_event(@link_stripped_event, measurements, metadata, _config) do
    Appsignal.increment_counter(
      "oli.instructor_dashboard.email.draft.link_stripped",
      Map.get(measurements, :count, 1),
      base_tags(metadata)
    )
  end

  def handle_event(_, _, _, _), do: :ok

  defp base_tags(metadata) do
    %{
      situation_key: normalize(metadata[:situation_key]),
      tone: normalize(metadata[:tone])
    }
  end

  defp attach_appsignal_handler do
    case :telemetry.attach_many(
           "instructor-dashboard-email-appsignal-handler",
           [@generated_event, @failed_event, @link_stripped_event],
           &__MODULE__.handle_event/4,
           %{}
         ) do
      :ok -> :ok
      {:error, :already_exists} -> :ok
    end
  end

  defp normalize(nil), do: "unknown"
  defp normalize(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize(value) when is_binary(value), do: value
  defp normalize(value), do: to_string(value)
end
