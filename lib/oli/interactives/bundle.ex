defmodule Oli.Interactives.Bundle do
  @moduledoc "Validates generated static bundles and stores each build under its own media prefix."
  alias ExAws.S3
  alias Oli.HTTP

  @max_bytes 50_000_000
  @max_entry_bytes 10_000_000
  @max_files 250

  @doc "Checks ZIP resource limits and paths before extraction, and validates the generated part manifest."
  @spec unpack(binary(), [integer()]) :: {:ok, map()} | {:error, String.t()}
  def unpack(zip, selected_ids) when is_binary(zip) and byte_size(zip) <= 20_000_000 do
    with {:ok, table} <- :zip.table(zip),
         entries <- Enum.filter(table, &match?({:zip_file, _, _, _, _, _}, &1)),
         true <- length(entries) <= @max_files,
         true <- Enum.all?(entries, &valid_entry?/1),
         true <-
           Enum.sum(Enum.map(entries, fn entry -> elem(elem(entry, 2), 1) end)) <= @max_bytes,
         {:ok, extracted} <- :zip.unzip(zip, [:memory]),
         files <-
           Enum.reject(extracted, fn {name, _} -> String.ends_with?(List.to_string(name), "/") end),
         paths <- Enum.map(files, fn {name, _} -> List.to_string(name) end),
         true <- length(Enum.uniq(paths)) == length(paths),
         files <- Map.new(files, fn {name, data} -> {List.to_string(name), data} end),
         true <- is_binary(files["index.html"]) and byte_size(files["index.html"]) > 0,
         {:ok, %{"version" => 1, "parts" => parts}} <- Jason.decode(files["manifest.json"] || ""),
         true <- valid_parts?(parts, selected_ids) do
      {:ok, %{files: files, parts: parts}}
    else
      _ ->
        {:error,
         "Invalid bundle: include index.html and a version 1 manifest with unique parts mapped to selected skills; use safe paths and stay within archive limits."}
    end
  end

  def unpack(_, _), do: {:error, "The generated ZIP exceeds the 20 MB compressed limit."}

  @doc "Loads a completed build's bounded static files for revision, without following public URLs."
  @spec load(String.t(), [integer()]) :: {:ok, map()} | {:error, String.t()}
  def load(build_id, selected_ids) do
    bucket = Application.fetch_env!(:oli, :s3_media_bucket_name)
    prefix = "interactives/#{build_id}/"

    with {:ok, %{body: %{contents: entries} = listing}} <-
           S3.list_objects(bucket, prefix: prefix, max_keys: @max_files + 1)
           |> HTTP.aws().request(),
         false <- listing[:is_truncated] in [true, "true"],
         true <- is_list(entries) and length(entries) in 1..@max_files,
         true <-
           Enum.all?(entries, fn entry ->
             String.starts_with?(entry.key, prefix) and
               object_size(entry) in 0..@max_entry_bytes
           end),
         true <- Enum.sum(Enum.map(entries, &object_size/1)) <= @max_bytes,
         {:ok, files} <- download_files(bucket, prefix, entries),
         {:ok, {_, zip}} <- :zip.create(~c"source.zip", files, [:memory]),
         {:ok, unpacked} <- unpack(zip, selected_ids) do
      {:ok, unpacked}
    else
      _ -> {:error, "Unable to load the existing Interactive bundle for revision."}
    end
  end

  defp object_size(%{size: size}) when is_integer(size), do: size

  defp object_size(%{size: size}) when is_binary(size) do
    case Integer.parse(size) do
      {value, ""} -> value
      _ -> -1
    end
  end

  defp object_size(_), do: -1

  defp download_files(bucket, prefix, entries) do
    Enum.reduce_while(entries, {:ok, []}, fn entry, {:ok, files} ->
      expected_size = object_size(entry)

      case S3.get_object(bucket, entry.key) |> HTTP.aws().request() do
        {:ok, %{body: data}} when is_binary(data) and byte_size(data) == expected_size ->
          {:cont,
           {:ok,
            [{String.replace_prefix(entry.key, prefix, "") |> String.to_charlist(), data} | files]}}

        _ ->
          {:halt, {:error, :download_failed}}
      end
    end)
  end

  @doc "Uploads validated files with their MIME types to interactives/<build UUID>/ in the media bucket."
  @spec upload(map(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def upload(%{files: files}, build_id) do
    bucket = Application.fetch_env!(:oli, :s3_media_bucket_name)
    prefix = "interactives/#{build_id}"

    result =
      Enum.reduce_while(files, :ok, fn {path, content}, :ok ->
        options = [
          content_type: MIME.from_path(path),
          cache_control: "public, max-age=31536000, immutable",
          encryption: "AES256"
        ]

        case S3.put_object(bucket, "#{prefix}/#{path}", content, options)
             |> HTTP.aws().request() do
          {:ok, _} -> {:cont, :ok}
          _ -> {:halt, :error}
        end
      end)

    case result do
      :ok ->
        base = Application.fetch_env!(:oli, :media_url) |> String.trim_trailing("/")

        {:ok,
         %{
           "buildId" => build_id,
           "bucket" => bucket,
           "prefix" => prefix,
           "indexUrl" => "#{base}/#{prefix}/index.html"
         }}

      :error ->
        cleanup(files, build_id)
        {:error, "Unable to upload the generated bundle to the media bucket."}
    end
  end

  @doc "Removes only the known files belonging to a failed build's unique prefix."
  def cleanup(files, build_id) do
    bucket = Application.fetch_env!(:oli, :s3_media_bucket_name)

    Enum.each(files, fn {path, _} ->
      S3.delete_object(bucket, "interactives/#{build_id}/#{path}") |> HTTP.aws().request()
    end)

    :ok
  end

  defp valid_entry?({:zip_file, name, info, _, _, _}) do
    path = List.to_string(name) |> String.trim_trailing("/")

    String.valid?(path) and path != "" and
      not String.starts_with?(path, "/") and not String.contains?(path, ["\\", "\0", ":"]) and
      Enum.all?(String.split(path, "/"), &(&1 not in ["", ".", ".."])) and
      elem(info, 2) in [:regular, :directory] and elem(info, 1) <= @max_entry_bytes
  end

  defp valid_parts?(parts, selected_ids) when is_list(parts) and length(parts) > 0 do
    Enum.all?(parts, fn
      %{"id" => id, "objectiveIds" => ids} when is_binary(id) and is_list(ids) ->
        String.trim(id) != "" and length(ids) > 0 and
          Enum.all?(ids, &(is_integer(&1) and &1 in selected_ids))

      _ ->
        false
    end) and length(Enum.uniq_by(parts, & &1["id"])) == length(parts)
  end

  defp valid_parts?(_, _), do: false
end
