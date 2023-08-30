defmodule Oli.Analytics.XAPI.Uploader do

  alias ExAws.S3
  alias Oli.HTTP
  alias Oli.Analytics.XAPI.Statement

  def upload(%Statement{category: category, category_id: category_id, type: type, type_id: type_id, body: body}) do
    bucket_name = Application.fetch_env!(:oli, :s3_xapi_bucket_name)
    upload_path = "#{category}/#{category_id}/#{type}/#{type_id}.json"

    contents = Jason.encode!(body)

    S3.put_object(bucket_name, upload_path, contents, [])
    |> HTTP.aws().request()
  end

end
