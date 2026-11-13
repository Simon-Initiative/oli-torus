defmodule Oli.Interactives.Runtime do
  @moduledoc "Publishes a versioned, media-origin runtime so saved bundles receive current platform integration."
  alias ExAws.S3
  alias Oli.HTTP

  @doc "Returns a managed media entry for a bundle ID, publishing shared runtime assets once per code version."
  @spec entry(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def entry(build_id) do
    with {:ok, build_id} <- Ecto.UUID.cast(build_id) do
      assets = assets()

      digest =
        :crypto.hash(:sha256, Enum.map(assets, &elem(&1, 1))) |> Base.encode16(case: :lower)

      prefix = "interactives/runtime/#{digest}"

      result =
        Cachex.fetch(:page_content_cache, {__MODULE__, digest}, fn _ ->
          case publish(assets, prefix) do
            :ok -> {:commit, :ready}
            _ -> {:ignore, :unavailable}
          end
        end)

      case result do
        {status, :ready} when status in [:ok, :commit] ->
          base = Application.fetch_env!(:oli, :media_url) |> String.trim_trailing("/")
          {:ok, "#{base}/#{prefix}/frame.html?#{URI.encode_query(%{bundle: build_id})}"}

        _ ->
          {:error, :unavailable}
      end
    else
      _ -> {:error, :invalid_bundle}
    end
  end

  @doc "Identifies the current managed-runtime cache entry for invalidation and diagnostics."
  def cache_key do
    digest =
      :crypto.hash(:sha256, Enum.map(assets(), &elem(&1, 1))) |> Base.encode16(case: :lower)

    {__MODULE__, digest}
  end

  defp assets do
    [
      {"frame.html",
       File.read!(Application.app_dir(:oli, "priv/interactives/runtime/frame.html")),
       "text/html"},
      {"torus.js", File.read!(Application.app_dir(:oli, "priv/interactives/workspace/torus.js")),
       "text/javascript"}
    ]
  end

  defp publish(assets, prefix) do
    bucket = Application.fetch_env!(:oli, :s3_media_bucket_name)

    Enum.reduce_while(assets, :ok, fn {name, body, mime}, _ ->
      options = [
        content_type: mime,
        cache_control: "public, max-age=31536000, immutable",
        encryption: "AES256"
      ]

      case S3.put_object(bucket, "#{prefix}/#{name}", body, options) |> HTTP.aws().request() do
        {:ok, _} -> {:cont, :ok}
        _ -> {:halt, :error}
      end
    end)
  end
end
