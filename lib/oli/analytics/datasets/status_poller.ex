defmodule Oli.Analytics.Datasets.StatusPoller do

  use Oban.Worker, queue: :default, max_attempts: 2

  alias Oli.Analytics.Datasets.Settings
  alias Oli.Analytics.Datasets

  @impl Oban.Worker
  def perform(%Oban.Job{} = _job) do
    if Settings.enabled?() do
      Datasets.update_job_statuses()
    else
      :ok
    end
  end

end
