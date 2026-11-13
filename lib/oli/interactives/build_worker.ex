defmodule Oli.Interactives.BuildWorker do
  @moduledoc "Short durable polling jobs for hosted Interactive builds."
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [
      period: :infinity,
      fields: [:args],
      states: [:available, :scheduled, :executing, :retryable]
    ]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"build_id" => id}}), do: Oli.Interactives.Builds.advance(id)
end
