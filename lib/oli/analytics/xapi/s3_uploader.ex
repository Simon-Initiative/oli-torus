defmodule Oli.Analytics.XAPI.S3Uploader do
  alias ExAws.S3
  alias Oli.HTTP
  alias Oli.Analytics.XAPI.StatementBundle

  def upload(%StatementBundle{
        partition: partition,
        partition_id: partition_id,
        category: category,
        bundle_id: bundle_id,
        body: body
      }) do
    bucket_name = Application.fetch_env!(:oli, :s3_xapi_bucket_name)

    {:ok, datetime} = DateTime.now("Etc/UTC")

    timestamp =
      DateTime.to_iso8601(datetime)
      |> String.replace(":", "-")

    upload_path = "#{partition}/#{partition_id}/#{category}/#{timestamp}_#{bundle_id}.jsonl"

    # We don't want the default 10 retries, which could lead to problems downstream
    # by delaying a batcher as we wait for a single upload to succeed
    retries_config = [
      max_attempts: 2,
      base_backoff_in_ms: 10,
      max_backoff_in_ms: 10_000
    ]

    :telemetry.span(
      [:oli, :xapi, :pipeline, :upload],
      %{
        category: category,
        partition: partition,
        partition_id: partition_id,
        bundle_id: bundle_id
      },
      fn ->
        result =
          S3.put_object(bucket_name, upload_path, body, [])
          |> HTTP.aws().request(retries: retries_config)

        {result, %{}}
      end
    )
  end
end
