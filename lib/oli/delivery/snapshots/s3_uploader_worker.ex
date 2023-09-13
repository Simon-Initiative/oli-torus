defmodule Oli.Delivery.Snapshots.S3UploaderWorker do
  use Oban.Worker, queue: :s3_uploader, max_attempts: 3

  alias Oli.Analytics.XAPI.{StatementBundle, Uploader}

  @moduledoc """
  An Oban worker to upload the snapshot details to S3 for cases where analytics v2 is supported.
  This worker finishes the work that was initialized in the SnapshotWorker (Oli.Delivery.Snapshots.Worker).

  If the job fails, it will be retried up to a total of the configured maximum attempts.
  """
  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"body" => body, "bundle_id" => bundle_id, "partition_id" => partition_id}
      }) do
    %StatementBundle{
      partition: :section,
      partition_id: partition_id,
      category: :attempt_evaluated,
      bundle_id: bundle_id,
      body: body
    }
    |> Uploader.upload()
  end
end
