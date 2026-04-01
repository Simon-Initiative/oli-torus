defmodule Mix.Tasks.Oli.Analytics.RebuildAdaptiveResponseSummaries do
  use Mix.Task

  @shortdoc "Rebuilds adaptive response summary rows from stored part attempts"

  @moduledoc """
  Rebuilds adaptive response summary rows from stored part attempts.

      mix oli.analytics.rebuild_adaptive_response_summaries
  """

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    case Oli.Analytics.Summary.rebuild_adaptive_response_summaries() do
      {:ok, activity_count} ->
        Mix.shell().info(
          "Rebuilt adaptive response summaries for #{activity_count} adaptive activities."
        )

      {:error, reason} ->
        Mix.raise("Failed to rebuild adaptive response summaries: #{inspect(reason)}")
    end
  end
end
