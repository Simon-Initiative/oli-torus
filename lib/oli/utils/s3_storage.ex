defmodule Oli.Utils.S3Storage do

  alias ExAws.S3
  alias Oli.HTTP

  @doc """
    Uploads a file to S3 given a bucket name, upload path, and current file path
  """
  @spec upload_file(binary, binary, binary | map) :: {:ok, any} | {:error, any}
  def upload_file(bucket_name, upload_path, file_path) when is_map(file_path) do
    upload_file(bucket_name, upload_path, file_path.path)
  end

  def upload_file(bucket_name, upload_path, file_path) do
    media_url = Application.fetch_env!(:oli, :media_url)

    full_upload_path = "http://#{media_url}/#{upload_path}"

    contents = File.read!(file_path)

    case upload(bucket_name, upload_path, contents) do
      {:ok, %{status_code: 200}} -> {:ok, full_upload_path}
      {_, payload} -> {:error, payload}
    end

  end

  defp upload(bucket_name, upload_path, contents) do
    S3.put_object(bucket_name, upload_path, contents, [{:acl, :public_read}])
    |> HTTP.aws().request()
  end
end
