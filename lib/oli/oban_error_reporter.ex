defmodule Oli.ObanErrorReporter do
  require Logger

  def handle_event([:oban, :job, :exception], _, meta, _) do
    context = Map.take(meta, [:id, :args, :queue, :worker, :stacktrace])

    Logger.error("Oban job failed", context)
  end
end
