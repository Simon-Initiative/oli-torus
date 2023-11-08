defmodule Oli.ObanErrorReporter do
  require Logger

  @doc false
  @spec handle_event([atom()], map(), map(), Keyword.t()) :: :ok
  def handle_event([:oban, :job, event], measure, meta, opts) do
    log(opts, fn ->
      details = Map.take(meta.job, ~w(attempt args id max_attempts meta queue tags worker)a)

      extra =
        case event do
          :start ->
            %{event: "job:start", system_time: measure.system_time}

          :stop ->
            %{
              duration: convert(measure.duration),
              event: "job:stop",
              queue_time: convert(measure.queue_time),
              state: meta.state
            }

          :exception ->
            %{
              error: Exception.format_banner(meta.kind, meta.reason, meta.stacktrace),
              event: "job:exception",
              duration: convert(measure.duration),
              queue_time: convert(measure.queue_time),
              state: meta.state
            }
        end

      if details[:attempt] >= details[:max_attempts] do
        IO.inspect(Map.merge(details, extra), label: "Oban job exceeded max attempts")
      end

      Map.merge(details, extra)
    end)
  end

  def handle_event([:oban, :job, :exception], _, meta, _) do
    context = Map.take(meta, [:id, :args, :queue, :worker, :stacktrace])

    Logger.error("Oban job failed", context)
  end

  defp convert(value), do: System.convert_time_unit(value, :native, :microsecond)

  defp log(opts, fun) do
    level = Keyword.fetch!(opts, :level)

    Logger.log(level, fn ->
      output = Map.put(fun.(), :source, "oban")

      if Keyword.fetch!(opts, :encode) do
        Jason.encode_to_iodata!(output)
      else
        output
      end
    end)
  end
end
