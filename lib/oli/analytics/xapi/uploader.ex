defmodule Oli.Analytics.XAPI.Uploader do

  alias ExAws.S3
  alias Oli.HTTP
  alias Oli.Analytics.XAPI.StatementBundle

  def upload(%StatementBundle{partition: partition, partition_id: partition_id, category: category, bundle_id: bundle_id, body: body}) do
    bucket_name = Application.fetch_env!(:oli, :s3_xapi_bucket_name)

    {:ok, datetime} = DateTime.now("Etc/UTC")
    timestamp = DateTime.to_iso8601(datetime)
    |> String.replace(":", "-")

    upload_path = "#{partition}/#{partition_id}/#{category}/#{timestamp}_#{bundle_id}.jsonl"

    S3.put_object(bucket_name, upload_path, body, [])
    |> HTTP.aws().request()
  end

end
