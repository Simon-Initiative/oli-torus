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
  @default_s3_operation_concurrency 8
  @default_s3_operation_timeout_ms 15_000
  @supporting_file_reference_regex Regex.compile!(
                                     "\\b(?:webcontent|media|super_media|bundles)/[A-Za-z0-9_./-]+\\.[A-Za-z0-9]{1,8}(?:[?#][^<>\"'\\s]*)?"
                                   )

  def export(%{} = model, resource_base) do
    manifest_xml = Map.get(model, "modelXml", "")
    verified_references = verified_supporting_files(Map.get(model, "resourceVerification"), nil)
    normalized_resource_base = normalize_media_directory(resource_base)
    extracted_references = extract_supporting_file_references(manifest_xml)

    with :ok <- validate_export_resource_base(normalized_resource_base, extracted_references),
         {:ok, manifest_references} <-
           resolve_referenced_supporting_files(manifest_xml, normalized_resource_base) do
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
             load_supporting_files(normalized_resource_base, referenced_files) do
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
  end

  defp validate_export_resource_base(normalized_resource_base, extracted_references) do
    cond do
      normalized_resource_base == "" and extracted_references != [] ->
        {:error, :missing_resource_base}

      true ->
        :ok
    end
  end

  def resolve_bundle_media_reference(reference, resource_base) when is_binary(reference) do
    normalized_directory = normalize_media_directory(resource_base)

    with true <- normalized_directory != "",
         {:ok, cleaned_reference} <- sanitize_reference(reference),
         {:ok, relative_path} <-
           resolve_relative_supporting_path(cleaned_reference, normalized_directory) do
      {:ok,
       %{
         reference: reference,
         relative_path: relative_path,
         key: Path.join(["media", normalized_directory, relative_path])
       }}
    else
      false -> {:error, {:invalid_reference, reference}}
      {:error, _reason} -> {:error, {:invalid_reference, reference}}
    end
  end

  def resolve_bundle_media_reference(reference, _resource_base),
    do: {:error, {:invalid_reference, reference}}

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
         :ok <- validate_archive_entry_paths(entries, manifest_file, supporting_files_path),
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
    normalized_resource_base = normalize_media_directory(resource_base)
    bucket_name = Application.fetch_env!(:oli, :s3_media_bucket_name)

    cond do
      normalized_resource_base == "" and MapSet.size(referenced_files) > 0 ->
        {:error, :missing_resource_base}

      true ->
        referenced_files
        |> Enum.sort()
        |> Enum.reduce_while({:ok, []}, fn reference, {:ok, acc} ->
          with {:ok, %{key: key, relative_path: zip_path}} <-
                 resolve_bundle_media_reference(reference, normalized_resource_base),
               {:ok, %{status_code: 200, body: body}} <-
                 S3.get_object(bucket_name, key) |> HTTP.aws().request() do
            {:cont, {:ok, [{zip_path, body} | acc]}}
          else
            {:error, _reason} = error ->
              {:halt, error}

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
               resource_base,
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
    |> parallel_s3_map(fn %{staged_key: staged_key, content: content} ->
      case upload_file(bucket_name, staged_key, content) do
        {:ok, %{status_code: 200}} -> {:ok, staged_key}
        _ -> {:error, {:staging_upload_failed, staged_key}}
      end
    end)
    |> case do
      {:ok, keys} -> {:ok, keys}
      {:error, reason, keys} -> {:error, reason, keys}
    end
  end

  defp backup_existing_destination_objects(
         bucket_name,
         supporting_objects,
         resource_base,
         backup_resource_base
       ) do
    with {:ok, existing_keys} <-
           list_existing_destination_keys(bucket_name, resource_base, supporting_objects) do
      copy_existing_destination_objects(
        bucket_name,
        supporting_objects,
        backup_resource_base,
        existing_keys
      )
    end
  end

  defp copy_existing_destination_objects(
         bucket_name,
         supporting_objects,
         backup_resource_base,
         existing_keys
       ) do
    supporting_objects
    |> parallel_s3_map(fn %{destination_key: destination_key, relative_path: path} ->
      if MapSet.member?(existing_keys, destination_key) do
        backup_key = Path.join(["media", backup_resource_base, path])

        case copy_object(bucket_name, backup_key, destination_key) do
          {:ok, %{status_code: 200}} ->
            {:ok, %{destination_key: destination_key, existed?: true, backup_key: backup_key}}

          _ ->
            {:error, {:backup_copy_failed, destination_key}}
        end
      else
        {:ok, %{destination_key: destination_key, existed?: false}}
      end
    end)
    |> case do
      {:ok, records} -> {:ok, records}
      {:error, reason, records} -> {:error, reason, records}
    end
  end

  defp promote_staged_objects(bucket_name, supporting_objects) do
    supporting_objects
    |> parallel_s3_map(fn %{staged_key: staged_key, destination_key: destination_key} ->
      case copy_object(bucket_name, destination_key, staged_key) do
        {:ok, %{status_code: 200}} ->
          {:ok, destination_key}

        _ ->
          {:error, {:promote_copy_failed, destination_key, staged_key}}
      end
    end)
    |> case do
      {:ok, promoted_keys} -> {:ok, promoted_keys}
      {:error, reason, promoted_keys} -> {:error, reason, promoted_keys}
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
    keys
    |> Task.async_stream(
      fn key -> delete_object(bucket_name, key) end,
      max_concurrency: s3_operation_concurrency(),
      ordered: false,
      timeout: s3_operation_timeout_ms(),
      on_timeout: :kill_task
    )
    |> Stream.run()
  end

  defp list_existing_destination_keys(bucket_name, _resource_base, supporting_objects) do
    supporting_objects
    |> parallel_s3_map(fn %{destination_key: destination_key} ->
      case object_exists(bucket_name, destination_key) do
        {:ok, true} -> {:ok, destination_key}
        {:ok, false} -> {:ok, nil}
        {:error, reason} -> {:error, {:backup_lookup_failed, destination_key, reason}}
      end
    end)
    |> case do
      {:ok, keys} ->
        {:ok, keys |> Enum.reject(&is_nil/1) |> MapSet.new()}

      {:error, reason, _keys} ->
        {:error, reason}
    end
  end

  defp parallel_s3_map(items, mapper) do
    items
    |> Task.async_stream(
      mapper,
      max_concurrency: s3_operation_concurrency(),
      ordered: true,
      timeout: s3_operation_timeout_ms(),
      on_timeout: :kill_task
    )
    |> Enum.reduce({[], nil}, fn
      {:ok, {:ok, value}}, {results, error} ->
        {[value | results], error}

      {:ok, {:error, reason}}, {results, nil} ->
        {results, reason}

      {:ok, {:error, _reason}}, {results, error} ->
        {results, error}

      {:exit, :timeout}, {results, nil} ->
        {results, {:s3_operation_timeout, s3_operation_timeout_ms()}}

      {:exit, :timeout}, {results, error} ->
        {results, error}

      {:exit, reason}, {results, nil} ->
        {results, {:task_exit, reason}}

      {:exit, _reason}, {results, error} ->
        {results, error}
    end)
    |> case do
      {results, nil} -> {:ok, Enum.reverse(results)}
      {results, error} -> {:error, error, Enum.reverse(results)}
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

  defp s3_operation_concurrency do
    config = Application.get_env(:oli, __MODULE__, [])
    Keyword.get(config, :s3_operation_concurrency, @default_s3_operation_concurrency)
  end

  defp s3_operation_timeout_ms do
    config = Application.get_env(:oli, __MODULE__, [])
    Keyword.get(config, :s3_operation_timeout_ms, @default_s3_operation_timeout_ms)
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

  defp validate_archive_entry_paths(entries, manifest_file, supporting_files_path) do
    supporting_prefix = normalize_supporting_path(supporting_files_path)

    entries
    |> Map.keys()
    |> Enum.reject(&allowed_archive_metadata_path?(&1, manifest_file))
    |> Enum.reduce_while(:ok, fn path, :ok ->
      case validate_archive_entry_path(path, supporting_prefix) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp allowed_archive_metadata_path?(path, manifest_file) do
    path in [@model_file, manifest_file]
  end

  defp validate_archive_entry_path(path, supporting_prefix) do
    cond do
      not String.starts_with?(path, supporting_prefix) ->
        {:error, {:invalid_archive_entry_path, path}}

      unsafe_path?(path) ->
        {:error, {:invalid_archive_entry_path, path}}

      true ->
        :ok
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
    model_xml
    |> extract_supporting_file_references()
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

  defp resolve_referenced_supporting_files(model_xml, resource_base) do
    model_xml
    |> extract_supporting_file_references()
    |> Enum.reduce_while({:ok, MapSet.new()}, fn reference, {:ok, acc} ->
      case resolve_bundle_media_reference(reference, resource_base) do
        {:ok, %{relative_path: relative_path}} ->
          {:cont, {:ok, MapSet.put(acc, relative_path)}}

        {:error, _reason} = error ->
          {:halt, error}
      end
    end)
  end

  defp extract_supporting_file_references(model_xml) when is_binary(model_xml) do
    Regex.scan(@supporting_file_reference_regex, model_xml)
    |> Enum.map(&List.first/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp extract_supporting_file_references(_), do: []

  defp sanitize_reference(reference) do
    cleaned_reference =
      reference
      |> String.trim()
      |> String.trim_leading("/")
      |> String.replace(~r/[?#].*$/, "")

    cond do
      cleaned_reference == "" ->
        {:error, :empty_reference}

      unsafe_path?(cleaned_reference) ->
        {:error, :unsafe_reference}

      true ->
        {:ok, cleaned_reference}
    end
  end

  defp resolve_relative_supporting_path(cleaned_reference, normalized_directory) do
    cond do
      String.starts_with?(cleaned_reference, @supporting_files_path) ->
        validate_supporting_path(cleaned_reference)

      String.starts_with?(cleaned_reference, normalized_directory <> "/") ->
        cleaned_reference
        |> String.replace_prefix(normalized_directory <> "/", "")
        |> validate_supporting_path()

      String.starts_with?(cleaned_reference, "media/" <> normalized_directory <> "/") ->
        cleaned_reference
        |> String.replace_prefix("media/" <> normalized_directory <> "/", "")
        |> validate_supporting_path()

      String.starts_with?(cleaned_reference, "super_media/" <> normalized_directory <> "/") ->
        cleaned_reference
        |> String.replace_prefix("super_media/" <> normalized_directory <> "/", "")
        |> validate_supporting_path()

      String.starts_with?(cleaned_reference, "bundles/") ->
        {:error, :foreign_bundle_reference}

      String.starts_with?(cleaned_reference, "media/") ->
        {:error, :foreign_media_reference}

      String.starts_with?(cleaned_reference, "super_media/") ->
        {:error, :foreign_super_media_reference}

      true ->
        {:error, :unsupported_reference}
    end
  end

  defp validate_supporting_path(path) do
    cond do
      not String.starts_with?(path, @supporting_files_path) ->
        {:error, :invalid_supporting_path}

      unsafe_path?(path) ->
        {:error, :unsafe_reference}

      true ->
        {:ok, path}
    end
  end

  defp unsafe_path?(path) do
    String.contains?(path, "\\") or
      String.starts_with?(path, "/") or
      path
      |> String.split("/", trim: true)
      |> Enum.any?(&(&1 == ".."))
  end

  defp copy_object(bucket_name, destination_key, source_key) do
    S3.put_object_copy(bucket_name, destination_key, bucket_name, source_key, acl: :public_read)
    |> HTTP.aws().request()
  end

  defp object_exists(bucket_name, key) do
    case S3.head_object(bucket_name, key) |> HTTP.aws().request() do
      {:ok, %{status_code: 200}} -> {:ok, true}
      {:error, {:http_error, 404, _response}} -> {:ok, false}
      other -> {:error, other}
    end
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
