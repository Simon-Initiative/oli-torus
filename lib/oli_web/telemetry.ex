defmodule OliWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    children = [
      {TelemetryMetricsPrometheus,
       [metrics: metrics(), port: Application.get_env(:oli, :prometheus_port)]},
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      last_value("vm.memory.total", unit: :byte),
      last_value("vm.total_run_queue_lengths.total"),
      last_value("vm.total_run_queue_lengths.cpu"),
      last_value("vm.total_run_queue_lengths.io"),
      last_value("vm.system_counts.process_count"),
      distribution("oli.plug.stop.duration",
        reporter_options: [buckets: 1..20 |> Enum.map(&(&1 * 25))],
        unit: {:native, :millisecond}
      ),
      distribution("oli.repo.query.total_time",
        reporter_options: [buckets: 1..40 |> Enum.map(&(&1 * 5))],
        unit: {:native, :millisecond}
      ),
      distribution("oli.resolvers.delivery.duration",
        reporter_options: [buckets: 1..40 |> Enum.map(&(&1 * 5))],
        unit: {:native, :millisecond}
      ),

      # Phoenix Metrics
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),

      # Plug
      counter("oli.plug.start.system_time"),
      summary("oli.plug.stop.duration", unit: {:native, :millisecond}),
      summary("oli.resolvers.authoring.duration"),
      summary("oli.resolvers.delivery.duration"),

      # Database Time Metrics
      summary("oli.repo.query.total_time", unit: {:native, :millisecond}),
      summary("oli.repo.query.decode_time", unit: {:native, :millisecond}),
      summary("oli.repo.query.query_time", unit: {:native, :millisecond}),
      summary("oli.repo.query.queue_time", unit: {:native, :millisecond}),
      summary("oli.repo.query.idle_time", unit: {:native, :millisecond}),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    []
  end
end
