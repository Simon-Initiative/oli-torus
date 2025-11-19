defmodule OliWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  @event [:torus, :feature, :exec]

  def start_link(arg), do: Supervisor.start_link(__MODULE__, arg, name: __MODULE__)

  def init(_arg) do
    children = []
    :ok = attach()
    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    non_distributed_metrics() ++
      [
        distribution("oli.plug.stop.duration",
          reporter_options: [buckets: Enum.map(1..20, &(&1 * 25))],
          unit: {:native, :millisecond}
        ),
        distribution("oli.repo.query.total_time",
          reporter_options: [buckets: Enum.map(1..40, &(&1 * 5))],
          unit: {:native, :millisecond}
        ),
        distribution("oli.resolvers.delivery.duration",
          reporter_options: [buckets: Enum.map(1..40, &(&1 * 5))],
          unit: {:native, :millisecond}
        )
      ]
  end

  def non_distributed_metrics do
    [
      last_value("vm.memory.total", unit: :byte),
      last_value("vm.total_run_queue_lengths.total"),
      last_value("vm.total_run_queue_lengths.cpu"),
      last_value("vm.total_run_queue_lengths.io"),
      last_value("vm.system_counts.process_count"),
      last_value("oli.xapi.pipeline.queue_size"),
      last_value("oli.xapi.pipeline.batch_size"),
      summary("oli.xapi.pipeline.upload.duration", unit: {:native, :millisecond}),
      summary("phoenix.endpoint.stop.duration", unit: {:native, :millisecond}),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),

      # Plug
      counter("oli.plug.start.count"),
      summary("oli.plug.stop.duration", unit: {:native, :millisecond}),
      summary("oli.resolvers.authoring.duration", unit: {:native, :millisecond}),
      summary("oli.resolvers.delivery.duration", unit: {:native, :millisecond}),
      summary("oli.analytics.summary.xapi", unit: {:native, :millisecond}),
      summary("oli.analytics.summary.resource_summary", unit: {:native, :millisecond}),
      summary("oli.analytics.summary.response_summary", unit: {:native, :millisecond}),
      summary("oli.analytics.summary.query", unit: {:native, :millisecond}),

      # DB
      summary("oli.repo.query.total_time", unit: {:native, :millisecond}),
      summary("oli.repo.query.decode_time", unit: {:native, :millisecond}),
      summary("oli.repo.query.query_time", unit: {:native, :millisecond}),
      summary("oli.repo.query.queue_time", unit: {:native, :millisecond}),
      summary("oli.repo.query.idle_time", unit: {:native, :millisecond})
    ]
  end

  def attach do
    :telemetry.attach_many(
      # make this unique to avoid double attach in dev
      "torus-appsignal-handler",
      [@event ++ [:start], @event ++ [:stop], @event ++ [:exception]],
      &__MODULE__.handle_event/4,
      %{}
    )
  end

  def handle_event([:torus, :feature, :exec, :stop], measurements, meta, _cfg) do
    tags = %{
      feature: Map.get(meta, :feature, "unknown"),
      stage: Map.get(meta, :stage, "unknown"),
      action: Map.get(meta, :action, "unknown")
    }

    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    Appsignal.add_distribution_value("torus.feature.duration_ms", duration_ms, tags)
    Appsignal.increment_counter("torus.feature.exec", 1, tags)

    unless Map.get(meta, :ok?, true),
      do: Appsignal.increment_counter("torus.feature.error", 1, tags)
  end

  def handle_event([:torus, :feature, :exec, :exception], _m, meta, _cfg) do
    tags = %{
      feature: Map.get(meta, :feature, "unknown"),
      stage: Map.get(meta, :stage, "unknown"),
      action: Map.get(meta, :action, "unknown"),
      kind: "exception"
    }

    Appsignal.increment_counter("torus.feature.error", 1, tags)
  end

  def handle_event(_, _, _, _), do: :ok
end
