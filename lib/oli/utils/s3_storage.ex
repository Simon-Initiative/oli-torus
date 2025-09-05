defmodule Oli.Utils.S3Storage do
  alias ExAws.S3
  alias Oli.HTTP

  @doc """
    Puts a file into S3 using a given bucket name, upload path, and file contents.
  """
  def put(bucket_name, upload_path, file_content) do
    media_url = Application.fetch_env!(:oli, :media_url)

    full_upload_path = "#{media_url}/#{upload_path}"

    case upload(bucket_name, upload_path, file_content) do
      {:ok, %{status_code: 200}} -> {:ok, full_upload_path}
      {_, payload} -> {:error, payload}
    end
  end

  def stream_file(bucket_name, upload_path, file_path) do
    media_url = Application.fetch_env!(:oli, :media_url)

    full_upload_path = "#{media_url}/#{upload_path}"

    case file_path
         |> S3.Upload.stream_file()
         |> S3.upload(bucket_name, upload_path)
         |> HTTP.aws().request() do
      {:ok, %{status_code: 200}} -> {:ok, full_upload_path}
      {_, payload} -> {:error, payload}
    end
  end

  def list_file_urls(path) do
    media_url = Application.fetch_env!(:oli, :media_url)
    bucket_name = Application.fetch_env!(:oli, :s3_media_bucket_name)

    S3.list_objects(bucket_name, prefix: path)
    |> HTTP.aws().request()
    |> case do
      {:ok, %{status_code: 200, body: %{contents: contents}}} ->
        {:ok, Enum.map(contents, fn obj -> "#{media_url}/#{obj.key}" end)}

      {_, payload} ->
        {:error, payload}
    end
  end

  @doc """
    Uploads a file to S3 given a bucket name, upload path, and current file path
  """
  @spec upload_file(binary, binary, binary | map) :: {:ok, any} | {:error, any}
  def upload_file(bucket_name, upload_path, file_path) when is_map(file_path) do
    upload_file(bucket_name, upload_path, file_path.path)
  end

  def upload_file(bucket_name, upload_path, file_path) do
    media_url = Application.fetch_env!(:oli, :media_url)

    full_upload_path = "#{media_url}/#{upload_path}"

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
