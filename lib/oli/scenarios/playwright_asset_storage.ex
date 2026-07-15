defmodule Oli.Scenarios.PlaywrightAssetStorage do
  @moduledoc """
  Reads private Playwright test assets (course archives, answer keys) from a
  dedicated object-storage bucket — MinIO in dev, S3 in other environments —
  using the ExAws configuration the application already has.

  These assets contain course IP and answer keys, so they must never live in
  the repository. Tests fetch them through
  `OliWeb.PlaywrightSupportAssetController.private_asset/2` instead of hitting
  the bucket directly, which keeps bucket credentials on the server side only.
  """

  alias ExAws.S3
  alias Oli.HTTP

  @type object_result ::
          {:ok, %{body: binary(), content_type: binary()}}
          | {:error, :invalid_key | :not_found | :request_failed | {:s3_error, integer()}}

  @doc """
  Fetches an object by key from the Playwright assets bucket.

  Returns `{:ok, %{body: binary, content_type: String.t()}}` on success, or
  `{:error, :invalid_key | :not_found | {:s3_error, status} | :request_failed}`.
  """
  @spec get_object(binary()) :: object_result()
  def get_object(key) do
    with :ok <- validate_key(key) do
      case S3.get_object(bucket_name(), key) |> HTTP.aws().request(aws_config()) do
        {:ok, %{status_code: 200, body: body, headers: headers}} ->
          {:ok, %{body: body, content_type: content_type(headers)}}

        {:ok, %{status_code: 404}} ->
          {:error, :not_found}

        {:ok, %{status_code: status}} ->
          {:error, {:s3_error, status}}

        {:error, {:http_error, 404, _}} ->
          {:error, :not_found}

        {:error, {:http_error, status, _}} ->
          {:error, {:s3_error, status}}

        {:error, _} ->
          {:error, :request_failed}
      end
    end
  end

  @doc """
  Uploads an object to the Playwright assets bucket. Intended for seeding a
  local MinIO (or a shared bucket) with the private test assets, e.g.:

      mix run -e 'Oli.Scenarios.PlaywrightAssetStorage.put_object(
        "mer-5672/answers.json", File.read!("/path/answers.json"), "application/json")'
  """
  @spec put_object(binary(), binary(), binary()) :: :ok | {:error, term()}
  def put_object(key, body, content_type) do
    with :ok <- validate_key(key) do
      case S3.put_object(bucket_name(), key, body, content_type: content_type)
           |> HTTP.aws().request(aws_config()) do
        {:ok, %{status_code: 200}} -> :ok
        other -> {:error, other}
      end
    end
  end

  @doc """
  Returns the configured Playwright assets bucket name.

  No hardcoded default: S3 bucket names are globally unique, so silently
  falling back to a fixed name risks writing/reading against a bucket
  someone else has already claimed if this ever points at real S3.
  """
  @spec bucket_name() :: binary()
  def bucket_name do
    case Application.get_env(:oli, :playwright_assets_bucket) do
      bucket when is_binary(bucket) and bucket != "" ->
        bucket

      _ ->
        raise "PLAYWRIGHT_ASSETS_BUCKET must be set to use the Playwright assets bucket"
    end
  end

  # runtime.exs points the global ex_aws config at real AWS even in dev, so
  # dev/test declare MinIO-friendly overrides under
  # :playwright_assets_s3_overrides. In environments that don't set them the
  # global (real S3) configuration applies untouched.
  defp aws_config do
    Application.get_env(:oli, :playwright_assets_s3_overrides, [])
  end

  # S3 keys are flat strings (no directory traversal exists), but reject
  # suspicious keys anyway to keep the endpoint's surface unambiguous.
  defp validate_key(key) do
    segments = String.split(key, "/")

    if key != "" and Enum.all?(segments, &valid_key_segment?/1) do
      :ok
    else
      {:error, :invalid_key}
    end
  end

  defp valid_key_segment?(segment), do: segment not in ["", ".", ".."]

  defp content_type(headers) do
    Enum.find_value(headers, "application/octet-stream", fn {name, value} ->
      if String.downcase(to_string(name)) == "content-type", do: value
    end)
  end
end
