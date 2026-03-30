defmodule Oli.Interop.CustomActivities.Package do
  alias ExAws.S3
  alias Oli.HTTP
  alias Oli.Utils

  @activity_type "oli_embedded"
  @format_version 1
  @model_file "model.json"
  @manifest_file "manifest.xml"
  @supporting_files_path "webcontent/"

  def export(%{} = model) do
    manifest_xml = Map.get(model, "modelXml", "")
    resource_base = Map.get(model, "resourceBase")
    manifest_references = referenced_supporting_files(manifest_xml, resource_base)

    verified_references =
      verified_supporting_files(Map.get(model, "resourceVerification"), resource_base)

    referenced_files =
      case {MapSet.size(manifest_references), MapSet.size(verified_references)} do
        {0, verified_count} when verified_count > 0 ->
          verified_references

        {_, verified_count} when verified_count > 0 ->
          MapSet.intersection(manifest_references, verified_references)

        _ ->
          manifest_references
      end

    with {:ok, supporting_files} <-
           load_supporting_files(resource_base, referenced_files) do
      package_model = build_package_model(model)

      entries =
        [
          {String.to_charlist(@model_file), Utils.pretty(package_model)},
          {String.to_charlist(@manifest_file), manifest_xml}
        ] ++
          Enum.map(supporting_files, fn {path, content} ->
            {String.to_charlist(path), content}
          end)

      {:ok, Utils.zip(entries, "embedded_activity_package.zip")}
    end
  end

  def import(upload_path, resource_base \\ nil)

  def import(upload_path, resource_base) when is_binary(upload_path) do
    with {:ok, entries} <- unzip(upload_path),
         {:ok, package_model} <- fetch_json_entry(entries, @model_file),
         :ok <- validate_package_model(package_model),
         manifest_file <- Map.get(package_model, "manifestXmlFile", @manifest_file),
         {:ok, manifest_xml} <- fetch_binary_entry(entries, manifest_file),
         supporting_files_path <-
           Map.get(package_model, "supportingFilesPath", @supporting_files_path),
         {:ok, {resource_base, resource_urls}} <-
           upload_supporting_files(entries, supporting_files_path, resource_base) do
      {:ok, build_imported_model(package_model, manifest_xml, resource_base, resource_urls)}
    end
  end

  defp build_package_model(model) do
    %{
      "version" => @format_version,
      "activityType" => @activity_type,
      "base" => Map.get(model, "base", "embedded"),
      "src" => Map.get(model, "src", "index.html"),
      "manifestXmlFile" => @manifest_file,
      "supportingFilesPath" => @supporting_files_path,
      "title" => Map.get(model, "title", "Embedded activity"),
      "stem" => Map.get(model, "stem", %{}),
      "authoring" => Map.get(model, "authoring", %{"parts" => [], "previewText" => ""}),
      "bibrefs" => Map.get(model, "bibrefs", [])
    }
  end

  defp build_imported_model(package_model, manifest_xml, resource_base, resource_urls) do
    %{
      "base" => Map.get(package_model, "base", "embedded"),
      "src" => Map.get(package_model, "src", "index.html"),
      "title" => Map.get(package_model, "title", "Embedded activity"),
      "stem" => Map.get(package_model, "stem", %{}),
      "authoring" => Map.get(package_model, "authoring", %{"parts" => [], "previewText" => ""}),
      "bibrefs" => Map.get(package_model, "bibrefs", []),
      "modelXml" => manifest_xml,
      "resourceBase" => resource_base,
      "resourceURLs" => resource_urls,
      "resourceVerification" => %{}
    }
  end

  defp load_supporting_files(resource_base, referenced_files) do
    normalized_directory = normalize_media_directory(resource_base)

    if normalized_directory == "" do
      {:ok, []}
    else
      bucket_name = Application.fetch_env!(:oli, :s3_media_bucket_name)

      referenced_files
      |> Enum.sort()
      |> Enum.reduce_while({:ok, []}, fn reference, {:ok, acc} ->
        key = resolve_media_key(reference, normalized_directory)
        zip_path = normalize_reference(reference, nil)

        case S3.get_object(bucket_name, key) |> HTTP.aws().request() do
          {:ok, %{status_code: 200, body: body}} ->
            {:cont, {:ok, [{zip_path, body} | acc]}}

          _ ->
            {:halt, {:error, :supporting_file_download_failed}}
        end
      end)
      |> case do
        {:ok, entries} -> {:ok, Enum.reverse(entries)}
        error -> error
      end
    end
  end

  defp upload_supporting_files(entries, supporting_files_path, existing_resource_base) do
    bucket_name = Application.fetch_env!(:oli, :s3_media_bucket_name)
    media_url = Application.fetch_env!(:oli, :media_url)
    supporting_prefix = normalize_supporting_path(supporting_files_path)

    resource_base =
      case normalize_media_directory(existing_resource_base) do
        "" -> "bundles/#{Ecto.UUID.generate()}"
        normalized -> normalized
      end

    entries
    |> Enum.filter(fn {path, _content} ->
      String.starts_with?(path, supporting_prefix) and not String.ends_with?(path, "/")
    end)
    |> Enum.sort_by(fn {path, _content} -> path end)
    |> Enum.reduce_while({:ok, []}, fn {path, content}, {:ok, urls} ->
      upload_path = Path.join(["/media", resource_base, path])

      case upload_file(bucket_name, upload_path, content) do
        {:ok, %{status_code: 200}} ->
          {:cont, {:ok, ["#{media_url}#{upload_path}" | urls]}}

        _ ->
          {:halt, {:error, :supporting_file_upload_failed}}
      end
    end)
    |> case do
      {:ok, urls} -> {:ok, {resource_base, Enum.reverse(urls)}}
      error -> error
    end
  end

  defp unzip(upload_path) do
    case :zip.unzip(String.to_charlist(upload_path), [:memory]) do
      {:ok, entries} ->
        {:ok,
         entries
         |> Enum.into(%{}, fn {path, content} ->
           {List.to_string(path), content}
         end)
         |> normalize_entry_root()}

      _ ->
        {:error, :invalid_package}
    end
  end

  defp normalize_entry_root(entries) do
    if Map.has_key?(entries, @model_file) do
      entries
    else
      case detect_wrapper_prefix(entries) do
        nil ->
          entries

        prefix ->
          entries
          |> Enum.reduce(%{}, fn {path, content}, acc ->
            case String.replace_prefix(path, prefix <> "/", "") do
              ^path -> acc
              "" -> acc
              normalized -> Map.put(acc, normalized, content)
            end
          end)
      end
    end
  end

  defp detect_wrapper_prefix(entries) do
    entries
    |> Map.keys()
    |> Enum.find_value(fn path ->
      if String.ends_with?(path, "/" <> @model_file) do
        String.trim_trailing(path, "/" <> @model_file)
      else
        nil
      end
    end)
  end

  defp fetch_json_entry(entries, path) do
    with {:ok, content} <- fetch_binary_entry(entries, path),
         {:ok, decoded} <- Jason.decode(content) do
      {:ok, decoded}
    else
      {:error, _reason} -> {:error, :invalid_package}
    end
  end

  defp fetch_binary_entry(entries, path) do
    case Map.fetch(entries, path) do
      {:ok, content} when is_binary(content) -> {:ok, content}
      _ -> {:error, :invalid_package}
    end
  end

  defp validate_package_model(%{"activityType" => @activity_type}), do: :ok
  defp validate_package_model(_), do: {:error, :invalid_package}

  defp normalize_media_directory(nil), do: ""

  defp normalize_media_directory(directory) do
    case String.trim(to_string(directory), "/") do
      "" -> ""
      "bundles/" <> _rest = normalized -> normalized
      normalized -> Path.join("bundles", normalized)
    end
  end

  defp normalize_supporting_path(path) when is_binary(path) do
    normalized = String.trim_leading(path, "/")

    cond do
      normalized == "" -> @supporting_files_path
      String.ends_with?(normalized, "/") -> normalized
      true -> normalized <> "/"
    end
  end

  defp referenced_supporting_files(model_xml, resource_base) when is_binary(model_xml) do
    Regex.compile!(
      "\\b(?:webcontent|media|super_media|bundles)/[A-Za-z0-9_./-]+\\.[A-Za-z0-9]{1,8}(?:[?#][^<>\"'\\s]*)?"
    )
    |> Regex.scan(model_xml)
    |> Enum.map(&List.first/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&normalize_reference(&1, resource_base))
    |> MapSet.new()
  end

  defp referenced_supporting_files(_, _), do: MapSet.new()

  defp verified_supporting_files(statuses, resource_base) when is_map(statuses) do
    statuses
    |> Enum.filter(fn {_reference, status} -> status == "verified" end)
    |> Enum.map(fn {reference, _status} -> normalize_reference(reference, resource_base) end)
    |> MapSet.new()
  end

  defp verified_supporting_files(_, _), do: MapSet.new()

  defp normalize_reference(value, _resource_base) when not is_binary(value), do: value

  defp normalize_reference(value, _resource_base) do
    normalized =
      value
      |> String.trim_leading("/")
      |> String.replace(~r/[?#].*$/, "")

    case String.split(normalized, "webcontent/", parts: 2) do
      [_, rest] -> "webcontent/" <> rest
      _ -> normalized
    end
  end

  defp resolve_media_key(reference, normalized_directory) do
    normalized_reference = normalize_reference(reference, normalized_directory)

    cond do
      String.starts_with?(normalized_reference, "media/") ->
        normalized_reference

      String.starts_with?(normalized_reference, "bundles/") ->
        Path.join(["media", normalized_reference])

      normalized_directory != "" ->
        Path.join(["media", normalized_directory, normalized_reference])

      true ->
        Path.join(["media", normalized_reference])
    end
  end

  defp upload_file(bucket, file_name, contents) do
    mime_type = MIME.from_path(file_name)

    options = [
      {:acl, :public_read},
      {:content_type, mime_type},
      {:cache_control, "no-cache, no-store, must-revalidate"}
    ]

    S3.put_object(bucket, file_name, contents, options) |> HTTP.aws().request()
  end
end
