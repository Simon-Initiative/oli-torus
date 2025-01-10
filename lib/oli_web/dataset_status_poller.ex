defmodule OliWeb.DatasetStatusPoller do

  use Oban.Worker, queue: :default, max_attempts: 2

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Analytics.Datasets.Settings
  alias Oli.Analytics.Datasets

  @impl Oban.Worker
  def perform(%Oban.Job{} = _job) do
    if Settings.enabled?() do
      case Datasets.update_job_statuses() do
        {:ok, to_notify} ->

          # Notify users of job status changes
          Datasets.notify_users(to_notify, fn slug, id ->
            Routes.live_path(OliWeb.Endpoint, OliWeb.Workspaces.CourseAuthor.DatasetDetailsLive, %{"project_id" => slug, "job_id" => id})
          end)
        {:error, _} ->
          :retry
      end
    else
      :ok
    end
  end

end
