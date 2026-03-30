defmodule Oli.Interop.CustomActivities.Package do
  alias ExAws.S3
  alias Oli.HTTP
  alias Oli.Utils

  @activity_type "oli_embedded"
  @format_version 1
  @model_file "model.json"
  @manifest_file "manifest.xml"
  @supporting_files_path "webcontent/"
  @default_max_archive_file_count 250
  @default_max_archive_uncompressed_bytes 50_000_000
  @default_max_archive_entry_bytes 10_000_000

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
    with :ok <- validate_archive_limits(upload_path),
         {:ok, entries} <- unzip(upload_path),
         {:ok, package_model} <- fetch_json_entry(entries, @model_file),
         :ok <- validate_package_model(package_model),
         manifest_file <- Map.get(package_model, "manifestXmlFile", @manifest_file),
         {:ok, manifest_xml} <- fetch_binary_entry(entries, manifest_file),
         supporting_files_path <-
           Map.get(package_model, "supportingFilesPath", @supporting_files_path),
         :ok <- validate_manifest_references(entries, manifest_xml, supporting_files_path),
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
    import_id = Ecto.UUID.generate()

    resource_base =
      case normalize_media_directory(existing_resource_base) do
        "" -> "bundles/#{Ecto.UUID.generate()}"
        normalized -> normalized
      end

    supporting_files =
      entries
      |> Enum.filter(fn {path, _content} ->
        String.starts_with?(path, supporting_prefix) and not String.ends_with?(path, "/")
      end)
      |> Enum.sort_by(fn {path, _content} -> path end)

    staged_resource_base = Path.join([resource_base, ".import-staging", import_id])
    backup_resource_base = Path.join([resource_base, ".import-backup", import_id])

    supporting_objects =
      build_supporting_objects(supporting_files, resource_base, staged_resource_base, media_url)

    case stage_supporting_objects(bucket_name, supporting_objects) do
      {:ok, staged_keys} ->
        case backup_existing_destination_objects(
               bucket_name,
               supporting_objects,
               backup_resource_base
             ) do
          {:ok, backup_records} ->
            case promote_staged_objects(bucket_name, supporting_objects) do
              {:ok, _promoted_keys} ->
                cleanup_objects(bucket_name, staged_keys)
                cleanup_objects(bucket_name, backup_keys(backup_records))

                {:ok, {resource_base, Enum.map(supporting_objects, & &1.url)}}

              {:error, reason, promoted_keys} ->
                rollback_result =
                  rollback_promoted_objects(bucket_name, promoted_keys, backup_records)

                cleanup_objects(bucket_name, staged_keys)
                cleanup_objects(bucket_name, backup_keys(backup_records))

                case rollback_result do
                  :ok ->
                    {:error, {:supporting_file_promote_failed, reason}}

                  {:error, rollback_reason} ->
                    {:error, {:supporting_file_promote_failed, reason, rollback_reason}}
                end
            end

          {:error, reason, backup_records} ->
            cleanup_objects(bucket_name, backup_keys(backup_records))
            cleanup_objects(bucket_name, staged_keys)
            {:error, {:supporting_file_backup_failed, reason}}
        end

      {:error, reason, staged_keys} ->
        cleanup_objects(bucket_name, staged_keys)
        {:error, {:supporting_file_staging_failed, reason}}
    end
  end

  defp build_supporting_objects(files, resource_base, staged_resource_base, media_url) do
    Enum.map(files, fn {path, content} ->
      destination_key = Path.join(["media", resource_base, path])
      staged_key = Path.join(["media", staged_resource_base, path])

      %{
        relative_path: path,
        content: content,
        staged_key: staged_key,
        destination_key: destination_key,
        url: "#{media_url}/#{destination_key}"
      }
    end)
  end

  defp stage_supporting_objects(bucket_name, supporting_objects) do
    supporting_objects
    |> Enum.reduce_while({:ok, []}, fn %{staged_key: staged_key, content: content}, {:ok, keys} ->
      case upload_file(bucket_name, staged_key, content) do
        {:ok, %{status_code: 200}} ->
          {:cont, {:ok, [staged_key | keys]}}

        _ ->
          {:halt, {:error, {:staging_upload_failed, staged_key}, Enum.reverse(keys)}}
      end
    end)
    |> case do
      {:ok, keys} -> {:ok, Enum.reverse(keys)}
      error -> error
    end
  end

  defp backup_existing_destination_objects(bucket_name, supporting_objects, backup_resource_base) do
    supporting_objects
    |> Enum.reduce_while({:ok, []}, fn %{destination_key: destination_key, relative_path: path},
                                       {:ok, records} ->
      case object_exists?(bucket_name, destination_key) do
        {:ok, false} ->
          {:cont, {:ok, [%{destination_key: destination_key, existed?: false} | records]}}

        {:ok, true} ->
          backup_key = Path.join(["media", backup_resource_base, path])

          case copy_object(bucket_name, backup_key, destination_key) do
            {:ok, %{status_code: 200}} ->
              {:cont,
               {:ok,
                [
                  %{destination_key: destination_key, existed?: true, backup_key: backup_key}
                  | records
                ]}}

            _ ->
              {:halt, {:error, {:backup_copy_failed, destination_key}, Enum.reverse(records)}}
          end

        {:error, reason} ->
          {:halt,
           {:error, {:backup_lookup_failed, destination_key, reason}, Enum.reverse(records)}}
      end
    end)
    |> case do
      {:ok, records} -> {:ok, Enum.reverse(records)}
      error -> error
    end
  end

  defp promote_staged_objects(bucket_name, supporting_objects) do
    supporting_objects
    |> Enum.reduce_while({:ok, []}, fn %{staged_key: staged_key, destination_key: destination_key},
                                       {:ok, promoted_keys} ->
      case copy_object(bucket_name, destination_key, staged_key) do
        {:ok, %{status_code: 200}} ->
          {:cont, {:ok, [destination_key | promoted_keys]}}

        _ ->
          {:halt,
           {:error, {:promote_copy_failed, destination_key, staged_key},
            Enum.reverse(promoted_keys)}}
      end
    end)
    |> case do
      {:ok, promoted_keys} -> {:ok, Enum.reverse(promoted_keys)}
      error -> error
    end
  end

  defp rollback_promoted_objects(bucket_name, promoted_keys, backup_records) do
    backup_records_by_destination =
      Map.new(backup_records, fn record -> {record.destination_key, record} end)

    promoted_keys
    |> Enum.reverse()
    |> Enum.reduce_while(:ok, fn destination_key, :ok ->
      case Map.fetch(backup_records_by_destination, destination_key) do
        {:ok, %{existed?: true, backup_key: backup_key}} ->
          case copy_object(bucket_name, destination_key, backup_key) do
            {:ok, %{status_code: 200}} -> {:cont, :ok}
            _ -> {:halt, {:error, {:rollback_restore_failed, destination_key, backup_key}}}
          end

        {:ok, %{existed?: false}} ->
          case delete_object(bucket_name, destination_key) do
            {:ok, %{status_code: status_code}} when status_code in [200, 204] ->
              {:cont, :ok}

            _ ->
              {:halt, {:error, {:rollback_delete_failed, destination_key}}}
          end

        :error ->
          {:halt, {:error, {:rollback_missing_backup_record, destination_key}}}
      end
    end)
  end

  defp backup_keys(backup_records) do
    backup_records
    |> Enum.filter(&Map.get(&1, :existed?, false))
    |> Enum.map(&Map.fetch!(&1, :backup_key))
  end

  defp cleanup_objects(bucket_name, keys) do
    Enum.each(keys, fn key ->
      _ = delete_object(bucket_name, key)
    end)
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

  defp validate_archive_limits(upload_path) do
    limits = archive_limits()

    with {:ok, table} <- archive_table(upload_path),
         file_entries <- archive_file_entries(table),
         :ok <- validate_archive_file_count(file_entries, limits.max_file_count),
         :ok <- validate_archive_entry_sizes(file_entries, limits.max_entry_bytes),
         :ok <- validate_archive_total_size(file_entries, limits.max_uncompressed_bytes) do
      :ok
    end
  end

  defp archive_limits do
    config = Application.get_env(:oli, __MODULE__, [])

    %{
      max_file_count:
        Keyword.get(config, :max_archive_file_count, @default_max_archive_file_count),
      max_uncompressed_bytes:
        Keyword.get(
          config,
          :max_archive_uncompressed_bytes,
          @default_max_archive_uncompressed_bytes
        ),
      max_entry_bytes:
        Keyword.get(config, :max_archive_entry_bytes, @default_max_archive_entry_bytes)
    }
  end

  defp archive_table(upload_path) do
    case :zip.table(String.to_charlist(upload_path)) do
      {:ok, table} -> {:ok, table}
      _ -> {:error, :invalid_package}
    end
  end

  defp archive_file_entries(table) do
    table
    |> Enum.flat_map(fn
      {:zip_file, path,
       {:file_info, size, type, _access, _atime, _mtime, _ctime, _mode, _links, _major_device,
        _minor_device, _inode, _uid, _gid}, _comment, _offset, _comp_size}
      when type != :directory ->
        [%{path: List.to_string(path), size: size}]

      _ ->
        []
    end)
  end

  defp validate_archive_file_count(file_entries, max_file_count) do
    if length(file_entries) > max_file_count do
      {:error, {:archive_file_count_exceeded, length(file_entries), max_file_count}}
    else
      :ok
    end
  end

  defp validate_archive_entry_sizes(file_entries, max_entry_bytes) do
    case Enum.find(file_entries, fn %{size: size} -> size > max_entry_bytes end) do
      nil ->
        :ok

      %{path: path, size: size} ->
        {:error, {:archive_entry_too_large, path, size, max_entry_bytes}}
    end
  end

  defp validate_archive_total_size(file_entries, max_uncompressed_bytes) do
    total_uncompressed_bytes =
      Enum.reduce(file_entries, 0, fn %{size: size}, total -> total + size end)

    if total_uncompressed_bytes > max_uncompressed_bytes do
      {:error,
       {:archive_uncompressed_size_exceeded, total_uncompressed_bytes, max_uncompressed_bytes}}
    else
      :ok
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

  defp validate_manifest_references(entries, manifest_xml, supporting_files_path) do
    normalized_supporting_path = normalize_supporting_path(supporting_files_path)

    manifest_references =
      referenced_supporting_files(manifest_xml, nil)
      |> Enum.filter(&String.starts_with?(&1, normalized_supporting_path))

    entry_paths =
      entries
      |> Map.keys()
      |> Enum.map(&normalize_reference(&1, nil))
      |> MapSet.new()

    missing_references =
      manifest_references
      |> Enum.reject(&MapSet.member?(entry_paths, &1))

    case missing_references do
      [] -> :ok
      missing -> {:error, {:missing_referenced_files, missing}}
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

  defp object_exists?(bucket_name, key) do
    case S3.list_objects(bucket_name, prefix: key, max_keys: 1) |> HTTP.aws().request() do
      {:ok, %{status_code: 200, body: %{contents: contents}}} ->
        {:ok,
         Enum.any?(contents, fn content ->
           case Map.get(content, :key) || Map.get(content, "Key") do
             ^key -> true
             _ -> false
           end
         end)}

      error ->
        {:error, error}
    end
  end

  defp copy_object(bucket_name, destination_key, source_key) do
    S3.put_object_copy(bucket_name, destination_key, bucket_name, source_key, acl: :public_read)
    |> HTTP.aws().request()
  end

  defp delete_object(bucket_name, key) do
    S3.delete_object(bucket_name, key) |> HTTP.aws().request()
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
