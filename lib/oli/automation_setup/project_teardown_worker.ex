defmodule Oli.AutomationSetup.ProjectTeardownWorker do
  @moduledoc """
  Performs complete automation-project cleanup outside the teardown request.

  Jobs run on a single-concurrency queue because deleting a full course can be
  database-intensive.
  """

  use Oban.Worker,
    queue: :automation_teardown,
    max_attempts: 3,
    unique: [
      fields: [:args, :worker],
      keys: [:project_slug],
      period: :infinity,
      states: [:available, :scheduled, :executing, :retryable]
    ]

  require Logger

  alias Oli.AutomationSetup

  @non_retryable_messages [
    "Can only delete projects with no authors",
    "Project allows duplicates"
  ]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"project_slug" => project_slug}}) do
    started_at = System.monotonic_time(:millisecond)
    Logger.info("automation_project_teardown started project=#{project_slug}")

    case AutomationSetup.teardown_project(project_slug) do
      %{success: true} ->
        Logger.info(
          "automation_project_teardown completed project=#{project_slug} " <>
            "duration_ms=#{System.monotonic_time(:millisecond) - started_at}"
        )

        :ok

      %{success: false, message: "Project not found"} ->
        Logger.info("automation_project_teardown already_completed project=#{project_slug}")
        :ok

      %{success: false, message: message} when message in @non_retryable_messages ->
        Logger.error(
          "automation_project_teardown cancelled project=#{project_slug} " <>
            "duration_ms=#{System.monotonic_time(:millisecond) - started_at} message=#{message}"
        )

        {:cancel, message}

      %{success: false} = result ->
        message = Map.get(result, :message, "Could not delete project")

        Logger.error(
          "automation_project_teardown failed project=#{project_slug} " <>
            "duration_ms=#{System.monotonic_time(:millisecond) - started_at} message=#{message}"
        )

        {:error, message}
    end
  end
end
