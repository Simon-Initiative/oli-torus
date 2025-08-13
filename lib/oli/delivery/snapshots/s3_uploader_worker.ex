defmodule Oli.Delivery.Snapshots.S3UploaderWorker do
  use Oban.Worker, queue: :s3_uploader, max_attempts: 3

  alias Oli.Analytics.XAPI.{StatementBundle, S3Uploader}

  @moduledoc """
  An Oban worker to upload a bundy of xAPI events.

  If the job fails, it will be retried up to a total of the configured maximum attempts.
  """
  def perform(%Oban.Job{
        args: %{
          "category" => category,
          "body" => body,
          "bundle_id" => bundle_id,
          "partition_id" => partition_id
        }
      }) do
    %StatementBundle{
      partition: :section,
      partition_id: partition_id,
      category: category,
      bundle_id: bundle_id,
      body: body
    }
    |> S3Uploader.upload()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"body" => body, "bundle_id" => bundle_id, "partition_id" => partition_id}
      }) do
    # No category specified, so default to :attempt_evaluated

    %StatementBundle{
      partition: :section,
      partition_id: partition_id,
      category: :attempt_evaluated,
      bundle_id: bundle_id,
      body: body
    }
    |> S3Uploader.upload()
  end
end
