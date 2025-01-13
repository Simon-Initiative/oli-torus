defmodule OliWeb.DatasetStatusPoller do

  require Logger

  use Oban.Worker, queue: :default, max_attempts: 2

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Analytics.Datasets.Settings
  alias Oli.Analytics.Datasets

  @impl Oban.Worker
  def perform(%Oban.Job{} = _job) do

    if Settings.enabled?() do

      Logger.info("Dataset status polling initiated")

      case Datasets.update_job_statuses() do
        {:ok, to_notify} ->

          Logger.info("Dataset polling update_job_statuses complete: #{Enum.count(to_notify)} jobs updated")

          # Notify users of terminal state changes
          Enum.filter(to_notify, fn {_id, status} -> Datasets.is_terminal_state?(status) end)
          |> Datasets.send_notification_emails(fn slug, id ->
            Routes.live_path(OliWeb.Endpoint, OliWeb.Workspaces.CourseAuthor.DatasetDetailsLive, %{"project_id" => slug, "job_id" => id})
          end)
        {:error, e} ->

          Logger.error("Dataset status polling failed: #{e}")
          :retry
      end
    else
      Logger.info("Dataset status polling is disabled")
      :ok
    end
  end

end
