defmodule Oli.Delivery.Attempts.Artifact do
  alias ExAws.S3
  alias ExAws

  defp upload_file(bucket, file_name, contents) do
    S3.put_object(bucket, file_name, contents, [{:acl, :public_read}]) |> ExAws.request()
  end

  def upload(section_slug, activity_attempt_guid, part_attempt_guid, file_name, file_contents) do
    path = "artifacts/#{section_slug}/#{activity_attempt_guid}/#{part_attempt_guid}/#{file_name}"
    bucket_name = Application.fetch_env!(:oli, :s3_media_bucket_name)

    media_url = Application.fetch_env!(:oli, :media_url)

    case upload_file(bucket_name, path, file_contents) do
      {:ok, %{status_code: 200}} ->
        {:ok, "#{media_url}/#{path}"}

      e ->
        IO.inspect(e)
        {:error, {:persistence}}
    end
  end
end
