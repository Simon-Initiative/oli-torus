defmodule Oli.Analytics.XAPI.FileWriterUploader do
  @moduledoc """
  This module is responsible for writing statement bundles to disk, instead of
  uploading them to S3 storage.  This is used for unit testing purposes.
  """

  alias Oli.Analytics.XAPI.StatementBundle

  def upload(%StatementBundle{body: "fail"}) do
    {:error, "Failed to upload bundle"}
  end

  def upload(%StatementBundle{} = bundle) do
    # write the bundle to a file in ./bundle_id.jsonl
    File.write("#{bundle.partition}/#{bundle.bundle_id}.jsonl", bundle.body)
  end
end
