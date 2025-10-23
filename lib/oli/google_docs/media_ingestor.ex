defmodule Oli.GoogleDocs.MediaIngestor do
  @moduledoc """
  Handles media ingestion for Google Docs imports by decoding base64 image data,
  enforcing size limits, deduplicating payloads, uploading new assets to the
  project media library, and returning structured ingestion results with
  warnings for any fallbacks.
  """

  alias Oli.Authoring.MediaLibrary
  alias Oli.GoogleDocs.MarkdownParser.MediaReference
  alias Oli.GoogleDocs.Warnings

  @default_max_image_bytes 5 * 1024 * 1024

  @type ingest_option ::
          {:project_slug, String.t()}
          | {:max_bytes, pos_integer()}
          | {:media_library, module()}

  defmodule Result do
    @moduledoc """
    Summary of media ingestion outcomes for a single import.
    """
    defstruct entries: %{},
              order: [],
              warnings: [],
              bytes_uploaded: 0,
              uploaded_count: 0,
              reused_count: 0,
              dedupe_hits: 0,
              skipped_count: 0,
              failed_count: 0
  end

  defmodule Entry do
    @moduledoc """
    Represents the ingestion outcome for a single media reference.
    """

    @enforce_keys [:id, :status, :source_url, :origin]
    defstruct [
      :id,
      :status,
      :source_url,
      :url,
      :bytes,
      :hash,
      :media_item,
      :origin,
      :filename,
      :reason,
      :source
    ]
  end

  @doc """
  Attempts to ingest each data URL-backed media reference, returning structured
  information about uploaded, reused, skipped, and failed assets.

  Options:
    * `:project_slug` (required) – project slug used for media library routing.
    * `:max_bytes` – per-image byte ceiling; defaults to 5 MiB.
    * `:media_library` – injectable module for persistence (defaults to `Oli.Authoring.MediaLibrary`).
  """
  @spec ingest([MediaReference.t()], [ingest_option()]) :: {:ok, Result.t()}
  def ingest(media_refs, opts \\ []) when is_list(media_refs) do
    project_slug = Keyword.fetch!(opts, :project_slug)
    max_bytes = Keyword.get(opts, :max_bytes, @default_max_image_bytes)
    media_library = Keyword.get(opts, :media_library, MediaLibrary)

    initial_result = %Result{}

    {result, _cache} =
      Enum.reduce(media_refs, {initial_result, %{}}, fn ref, acc ->
        ingest_one(ref, project_slug, max_bytes, media_library, acc)
      end)

    {:ok, finalize(result)}
  end

  defp finalize(%Result{} = result) do
    %{result | warnings: Enum.reverse(result.warnings), order: Enum.reverse(result.order)}
  end

  defp ingest_one(
         %MediaReference{} = ref,
         project_slug,
         max_bytes,
         media_library,
         {%Result{} = result, cache}
       ) do
    case ref.origin do
      :data_url ->
        handle_data_url(ref, project_slug, max_bytes, media_library, result, cache)

      _other ->
        entry =
          %Entry{
            id: ref.id,
            status: :skipped_remote,
            source_url: ref.src,
            url: ref.src,
            origin: ref.origin,
            filename: ref.filename
          }

        {%Result{} = updated, cache} = {add_entry(result, entry), cache}
        {updated, cache}
    end
  end

  defp handle_data_url(ref, project_slug, max_bytes, media_library, result, cache) do
    cond do
      not is_binary(ref.data) or ref.data == "" ->
        warning = build_decode_warning(ref)
        entry = failed_entry(ref, :missing_data, warning)
        {add_entry(result, entry, [warning]), cache}

      true ->
        case decode_base64(ref.data) do
          {:ok, binary} ->
            case enforce_size(binary, max_bytes) do
              :ok ->
                hash = sha256(binary)

                case Map.get(cache, hash) do
                  nil ->
                    do_ingest_unique(
                      ref,
                      binary,
                      hash,
                      project_slug,
                      media_library,
                      result,
                      cache
                    )

                  cached_entry ->
                    entry =
                      %Entry{
                        id: ref.id,
                        status: :reused,
                        source_url: ref.src,
                        url: cached_entry.url,
                        bytes: cached_entry.bytes,
                        hash: cached_entry.hash,
                        media_item: cached_entry.media_item,
                        origin: ref.origin,
                        filename: cached_entry.filename,
                        source: :cache
                      }

                    warning = build_dedupe_warning(ref, cached_entry.hash)
                    {add_entry(result, entry, [warning]), cache}
                end

              {:error, {:oversized, %{limit: limit}}} ->
                warning = build_oversized_warning(ref, limit)

                entry = %Entry{
                  id: ref.id,
                  status: :skipped_oversized,
                  source_url: ref.src,
                  url: ref.src,
                  origin: ref.origin,
                  filename: ref.filename,
                  reason: :oversized
                }

                {add_entry(result, entry, [warning]), cache}
            end

          {:error, :invalid_base64} ->
            warning = build_decode_warning(ref)
            entry = failed_entry(ref, :invalid_base64, warning)
            {add_entry(result, entry, [warning]), cache}
        end
    end
  end

  defp do_ingest_unique(
         ref,
         binary,
         hash,
         project_slug,
         media_library,
         result,
         cache
       ) do
    filename = build_filename(ref, hash)
    size = byte_size(binary)

    case media_library.add(project_slug, filename, binary) do
      {:ok, media_item} ->
        entry =
          %Entry{
            id: ref.id,
            status: :uploaded,
            source_url: ref.src,
            url: media_item.url,
            bytes: size,
            hash: hash,
            media_item: media_item,
            origin: ref.origin,
            filename: filename,
            source: :uploaded
          }

        {add_entry(result, entry), Map.put(cache, hash, entry)}

      {:duplicate, media_item} ->
        entry =
          %Entry{
            id: ref.id,
            status: :reused,
            source_url: ref.src,
            url: media_item.url,
            bytes: size,
            hash: hash,
            media_item: media_item,
            origin: ref.origin,
            filename: filename,
            source: :library
          }

        warning = build_dedupe_warning(ref, hash)
        {add_entry(result, entry, [warning]), Map.put(cache, hash, entry)}

      {:error, reason} ->
        warning = build_upload_warning(ref, reason)
        entry = failed_entry(ref, reason, warning)
        {add_entry(result, entry, [warning]), cache}
    end
  end

  defp add_entry(%Result{} = result, %Entry{} = entry, warnings \\ []) do
    result =
      %{
        result
        | entries: Map.put(result.entries, entry.id, entry),
          order: [entry.id | result.order]
      }
      |> update_counters(entry)

    Enum.reduce(List.wrap(warnings), result, fn
      nil, acc -> acc
      warning, acc -> %{acc | warnings: [warning | acc.warnings]}
    end)
  end

  defp update_counters(result, %Entry{status: :uploaded, bytes: bytes}) do
    %{
      result
      | uploaded_count: result.uploaded_count + 1,
        bytes_uploaded: result.bytes_uploaded + (bytes || 0)
    }
  end

  defp update_counters(result, %Entry{status: :reused}) do
    %{result | reused_count: result.reused_count + 1, dedupe_hits: result.dedupe_hits + 1}
  end

  defp update_counters(result, %Entry{status: status})
       when status in [:skipped_remote, :skipped_oversized] do
    %{result | skipped_count: result.skipped_count + 1}
  end

  defp update_counters(result, %Entry{status: :failed}) do
    %{result | failed_count: result.failed_count + 1}
  end

  defp update_counters(result, _entry), do: result

  defp decode_base64(data) do
    case Base.decode64(data, ignore: :whitespace) do
      {:ok, binary} -> {:ok, binary}
      :error -> {:error, :invalid_base64}
    end
  end

  defp enforce_size(binary, max_bytes) do
    if byte_size(binary) > max_bytes do
      {:error, {:oversized, %{limit: max_bytes}}}
    else
      :ok
    end
  end

  defp sha256(binary) do
    :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
  end

  defp build_filename(ref, hash) do
    base =
      ref.filename ||
        ref.title ||
        ref.alt ||
        "image"

    sanitized =
      base
      |> String.trim()
      |> String.normalize(:nfd)
      |> String.replace(~r/[\p{Mn}]/u, "")
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/u, "-")
      |> String.trim("-")

    ext = extension_from_mime(ref.mime_type)
    prefix = if sanitized == "", do: "image", else: sanitized

    "#{prefix}-#{String.slice(hash, 0, 8)}.#{ext}"
  end

  defp extension_from_mime(nil), do: "bin"

  defp extension_from_mime(mime_type) do
    case MIME.extensions(mime_type) do
      [ext | _] -> ext
      _ -> "bin"
    end
  end

  defp build_decode_warning(ref) do
    Warnings.build(:media_decode_failed, %{
      media_id: ref.id,
      filename: display_name(ref)
    })
  end

  defp build_oversized_warning(ref, limit) do
    Warnings.build(:media_oversized, %{
      media_id: ref.id,
      filename: display_name(ref),
      limit_mb: format_megabytes(limit)
    })
  end

  defp build_upload_warning(ref, reason) do
    Warnings.build(:media_upload_failed, %{
      media_id: ref.id,
      filename: display_name(ref),
      reason: format_reason(reason)
    })
  end

  defp build_dedupe_warning(ref, hash) do
    Warnings.build(:media_dedupe_warning, %{
      media_id: ref.id,
      hash_prefix: String.slice(hash || "", 0, 8)
    })
  end

  defp display_name(ref) do
    ref.filename || ref.title || ref.alt || ref.id || "inline image"
  end

  defp format_reason(%Ecto.Changeset{} = changeset), do: inspect(changeset.errors)
  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)

  defp format_megabytes(bytes) do
    megabytes = bytes / 1_048_576
    :erlang.float_to_binary(megabytes, decimals: 1)
  end

  defp failed_entry(ref, reason, _warning) do
    %Entry{
      id: ref.id,
      status: :failed,
      source_url: ref.src,
      url: ref.src,
      reason: reason,
      origin: ref.origin,
      filename: ref.filename
    }
  end
end
