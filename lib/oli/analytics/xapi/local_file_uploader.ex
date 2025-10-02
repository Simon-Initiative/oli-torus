# lib/oli/analytics/xapi/local_file_uploader.ex
defmodule Oli.Analytics.XAPI.LocalFileUploader do
  @moduledoc """
  Local file system uploader for XAPI statements.
  Writes JSONL files to a local directory instead of S3.
  """

  alias Oli.Analytics.XAPI.StatementBundle

  def upload(%StatementBundle{
        partition: partition,
        partition_id: partition_id,
        category: category,
        bundle_id: bundle_id,
        body: body
      }) do
    config = Application.fetch_env!(:oli, :xapi_upload_pipeline)

    base_dir = Keyword.get(config, :xapi_local_output_dir, "./xapi_output")

    {:ok, datetime} = DateTime.now("Etc/UTC")

    timestamp =
      DateTime.to_iso8601(datetime)
      |> String.replace(":", "-")

    # Create directory structure: base_dir/partition/partition_id/category/
    output_dir =
      Path.join([base_dir, to_string(partition), to_string(partition_id), to_string(category)])

    File.mkdir_p!(output_dir)

    # Create filename: timestamp_bundle_id.jsonl
    filename = "#{timestamp}_#{bundle_id}.jsonl"
    file_path = Path.join(output_dir, filename)

    case File.write(file_path, body) do
      :ok -> {:ok, %{file_path: file_path}}
      {:error, reason} -> {:error, reason}
    end
  end
end
