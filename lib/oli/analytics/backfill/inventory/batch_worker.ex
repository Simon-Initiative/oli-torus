defmodule Oli.Analytics.Backfill.Inventory.BatchWorker do
  @moduledoc """
  Processes a single parquet-described batch of JSONL objects and streams them into ClickHouse.
  """

  use Oban.Worker,
    queue: :clickhouse_inventory_batches,
    max_attempts: 5,
    unique: [
      fields: [:args, :worker],
      keys: [:batch_id],
      states: [:available, :scheduled, :retryable, :executing]
    ]

  require Logger

  alias Oli.Analytics.Backfill.BackfillRun
  alias Oli.Analytics.Backfill.Inventory
  alias Oli.Analytics.Backfill.InventoryBatch
  alias Oli.Analytics.Backfill.InventoryRun
  alias Oli.Analytics.Backfill.QueryBuilder
  alias Oli.Analytics.ClickhouseAnalytics
  alias Oli.Repo

  @status_poll_attempts 12
  @status_poll_interval_ms 1_000
  @interruption_check_every_chunks 5
  @interruption_check_every_entries 10

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"batch_id" => batch_id}}) when is_integer(batch_id) do
    batch = load_batch(batch_id)

    case ensure_batch_runnable(batch) do
      {:discard, reason} ->
        Logger.info("Discarding inventory batch #{batch.id}: #{reason}")
        {:discard, reason}

      :ok ->
        execute(batch.run, batch)
    end
  end

  def perform(%Oban.Job{args: %{"batch_id" => batch_id}}) do
    case Integer.parse(to_string(batch_id)) do
      {int, _} -> perform(%Oban.Job{args: %{"batch_id" => int}})
      :error -> {:discard, "invalid batch id"}
    end
  end

  defp execute(%InventoryRun{} = run, %InventoryBatch{} = batch) do
    with {:ok, batch} <- Inventory.transition_batch(batch, :running, %{error: nil}),
         {:ok, creds} <- inventory_credentials(run),
         {:ok, total_objects} <- manifest_entry_count(run, batch, creds),
         {:ok, batch} <- annotate_batch(batch, total_objects) do
      case ingest_entries(run, batch, creds) do
        {:ok, summary, batch} ->
          finalize_completed(run, batch, summary)

        {:paused, summary, batch} ->
          finalize_paused(run, batch, summary)

        {:cancelled, _summary, batch} ->
          finalize_cancelled(run, batch)

        {:error, reason} ->
          handle_failure(run, batch, reason)
      end
    else
      {:error, reason} ->
        handle_failure(run, batch, reason)
    end
  end

  defp finalize_completed(run, batch, summary) do
    with {:ok, batch} <- Inventory.transition_batch(batch, :completed, summary),
         {:ok, run} <- Inventory.recompute_run_aggregates(run),
         :ok <- update_run_progress(run),
         :ok <- Inventory.maybe_enqueue_pending_batches(run) do
      {:ok, batch}
    else
      {:error, reason} -> handle_failure(run, batch, reason)
    end
  end

  defp finalize_paused(run, batch, summary) do
    metadata =
      summary.metadata
      |> ensure_map()
      |> Map.delete("pause_requested")
      |> Map.delete("pause_requested_at")
      |> Map.put("paused_at", DateTime.utc_now())

    attrs = %{
      processed_objects: summary.processed_objects,
      rows_ingested: summary.rows_ingested,
      bytes_ingested: summary.bytes_ingested,
      metadata: metadata
    }

    with {:ok, batch} <- Inventory.transition_batch(batch, :paused, attrs),
         {:ok, run} <- Inventory.recompute_run_aggregates(run),
         :ok <- update_run_progress(run),
         :ok <- Inventory.maybe_enqueue_pending_batches(run) do
      {:ok, batch}
    else
      {:error, reason} -> handle_failure(run, batch, reason)
    end
  end

  defp finalize_cancelled(run, batch) do
    :ok = Inventory.maybe_enqueue_pending_batches(run)
    {:ok, batch}
  end

  defp ensure_batch_runnable(%InventoryBatch{status: status})
       when status in [:pending, :queued, :failed, :running],
       do: :ok

  defp ensure_batch_runnable(%InventoryBatch{status: status}),
    do: {:discard, "batch already #{status}"}

  defp load_batch(batch_id) do
    Repo.get!(InventoryBatch, batch_id)
    |> Repo.preload(:run)
  end

  defp fetch_manifest_page(
         %InventoryRun{} = run,
         %InventoryBatch{} = batch,
         creds,
         limit,
         offset
       ) do
    sanitized_limit = sanitize_positive_integer(limit)
    sanitized_offset = sanitize_non_negative_integer(offset)

    query =
      parquet_select_sql(run, batch, creds,
        limit: sanitized_limit,
        offset: sanitized_offset
      )

    case ClickhouseAnalytics.execute_query(
           query,
           "inventory manifest batch #{batch.id} page offset #{sanitized_offset || 0}"
         ) do
      {:ok, %{parsed_body: %{"data" => data}}} when is_list(data) ->
        {:ok, Enum.map(data, &normalize_manifest_row/1)}

      {:ok, %{parsed_body: data}} when is_list(data) ->
        {:ok, Enum.map(data, &normalize_manifest_row/1)}

      {:ok, _} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_manifest_row(row) when is_map(row) do
    %{
      bucket: fetch_value(row, ["bucket", :bucket]),
      key: fetch_value(row, ["key", :key])
    }
  end

  defp normalize_manifest_row(_), do: %{bucket: nil, key: nil}

  defp annotate_batch(%InventoryBatch{} = batch, total) do
    total = parse_positive_integer(total, 0)

    metadata =
      batch.metadata
      |> ensure_map()
      |> Map.put("object_count", total)
      |> Map.put("chunk_count", fetch_chunk_progress(batch))
      |> Map.put("chunk_sequence", fetch_chunk_sequence(batch))

    processed =
      batch.processed_objects
      |> parse_positive_integer(0)

    Inventory.update_batch(batch, %{
      object_count: total,
      processed_objects: processed,
      metadata: metadata
    })
  end

  defp ingest_entries(%InventoryRun{} = run, %InventoryBatch{} = batch, creds) do
    chunk_size = determine_chunk_size(run)
    page_size = determine_manifest_page_size(run, chunk_size)

    metadata =
      batch.metadata
      |> ensure_map()
      |> Map.put("dry_run", run.dry_run)

    initial_chunk_count =
      metadata
      |> Map.get("chunk_count", 0)
      |> parse_positive_integer(0)

    initial_chunk_sequence =
      metadata
      |> Map.get("chunk_sequence", initial_chunk_count)
      |> parse_positive_integer(initial_chunk_count)

    metadata =
      metadata
      |> Map.put("chunk_count", initial_chunk_count)
      |> Map.put("chunk_sequence", initial_chunk_sequence)

    initial_processed =
      batch.processed_objects
      |> parse_positive_integer(0)

    initial_rows =
      batch.rows_ingested
      |> parse_positive_integer(0)

    initial_bytes =
      batch.bytes_ingested
      |> parse_positive_integer(0)

    initial_summary = %{
      processed_objects: initial_processed,
      rows_ingested: initial_rows,
      bytes_ingested: initial_bytes,
      metadata: metadata
    }

    paginate_manifest_entries(
      run,
      batch,
      creds,
      chunk_size,
      page_size,
      initial_processed,
      initial_summary
    )
  end

  defp paginate_manifest_entries(
         %InventoryRun{} = run,
         %InventoryBatch{} = batch,
         creds,
         chunk_size,
         page_size,
         offset,
         summary
       ) do
    case fetch_manifest_page(run, batch, creds, page_size, offset) do
      {:ok, []} ->
        {:ok, summary, batch}

      {:ok, entries} ->
        case process_manifest_entries(run, batch, entries, chunk_size, creds, summary) do
          {:ok, updated_summary, updated_batch} ->
            paginate_manifest_entries(
              run,
              updated_batch,
              creds,
              chunk_size,
              page_size,
              offset + length(entries),
              updated_summary
            )

          {:paused, updated_summary, updated_batch} ->
            {:paused, updated_summary, updated_batch}

          {:cancelled, updated_summary, updated_batch} ->
            {:cancelled, updated_summary, updated_batch}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_manifest_entries(
         %InventoryRun{} = run,
         %InventoryBatch{} = batch,
         entries,
         chunk_size,
         creds,
         summary
       ) do
    date_range =
      case Inventory.extract_date_range(run.metadata) do
        {:ok, %{start: nil, end: nil}} ->
          nil

        {:ok, range} ->
          range

        {:error, reason} ->
          Logger.warning(
            "Inventory run #{run.id} has invalid date range filter: #{inspect(reason)}"
          )

          nil
      end

    {filtered_entries, skipped_count} =
      entries
      |> Enum.filter(&valid_entry?/1)
      |> filter_entries_by_date_range(date_range, run)

    with {:ok, summary, batch} <- apply_skipped_entries(summary, batch, skipped_count) do
      grouped_entries =
        filtered_entries
        |> Enum.group_by(& &1.bucket)

      grouped_entries
      |> Enum.reduce_while({:ok, summary, batch}, fn {bucket, bucket_entries},
                                                     {:ok, acc_summary, acc_batch} ->
        case check_for_interruption(acc_batch) do
          {:ok, refreshed_batch} ->
            case process_bucket(
                   run,
                   refreshed_batch,
                   bucket,
                   bucket_entries,
                   chunk_size,
                   creds,
                   acc_summary
                 ) do
              {:ok, updated_summary, updated_batch} ->
                {:cont, {:ok, updated_summary, updated_batch}}

              {:paused, updated_summary, updated_batch} ->
                {:halt, {:paused, updated_summary, updated_batch}}

              {:cancelled, updated_summary, updated_batch} ->
                {:halt, {:cancelled, updated_summary, updated_batch}}

              {:error, reason} ->
                {:halt, {:error, reason}}
            end

          {:paused, refreshed_batch} ->
            {:halt, {:paused, acc_summary, refreshed_batch}}

          {:cancelled, refreshed_batch} ->
            {:halt, {:cancelled, acc_summary, refreshed_batch}}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
      end)
      |> case do
        {:ok, summary, batch} ->
          {:ok, summary, batch}

        {:paused, summary, batch} ->
          {:paused, summary, batch}

        {:cancelled, summary, batch} ->
          {:cancelled, summary, batch}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp apply_skipped_entries(summary, batch, 0), do: {:ok, summary, batch}

  defp apply_skipped_entries(summary, %InventoryBatch{} = batch, skipped_count) do
    summary_metadata =
      summary
      |> Map.get(:metadata)
      |> ensure_map()
      |> Map.update("skipped_objects", skipped_count, &(&1 + skipped_count))

    updated_summary =
      summary
      |> Map.put(:processed_objects, Map.get(summary, :processed_objects, 0) + skipped_count)
      |> Map.put(:metadata, summary_metadata)

    processed_total =
      batch
      |> Map.get(:processed_objects)
      |> parse_positive_integer(0)
      |> Kernel.+(skipped_count)

    batch_metadata =
      batch.metadata
      |> ensure_map()
      |> Map.update("skipped_objects", skipped_count, &(&1 + skipped_count))

    case Inventory.update_batch(batch, %{
           processed_objects: processed_total,
           metadata: batch_metadata
         }) do
      {:ok, updated_batch} ->
        log_skipped_entries(batch, skipped_count)
        {:ok, updated_summary, updated_batch}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp apply_skipped_entries(summary, batch, _count), do: {:ok, summary, batch}

  defp log_skipped_entries(%InventoryBatch{} = batch, skipped_count) do
    Logger.debug(
      "Inventory batch #{batch.id} skipped #{skipped_count} manifest entries outside configured range"
    )
  end

  defp log_skipped_entries(_batch, _count), do: :ok

  defp manifest_entry_count(%InventoryRun{} = run, %InventoryBatch{} = batch, creds) do
    query = parquet_count_sql(run, batch, creds)

    case ClickhouseAnalytics.execute_query(
           query,
           "inventory manifest count #{batch.id}"
         ) do
      {:ok, %{parsed_body: %{"data" => [row | _]}}} when is_map(row) ->
        count =
          fetch_value(row, ["object_count", :object_count, "count", :count])
          |> parse_positive_integer(0)

        {:ok, count}

      {:ok, _} ->
        {:ok, 0}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_bucket(run, batch, bucket, entries, chunk_size, creds, summary) do
    entries
    |> Enum.chunk_every(chunk_size, chunk_size, [])
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, summary, batch}, fn {chunk, index},
                                                   {:ok, acc_summary, acc_batch} ->
      case maybe_check_for_interruption(acc_batch, index, @interruption_check_every_chunks) do
        {:ok, refreshed_batch} ->
          case process_chunk(
                 run,
                 refreshed_batch,
                 bucket,
                 chunk,
                 index,
                 creds,
                 acc_summary
               ) do
            {:ok, updated_summary, updated_batch} ->
              {:cont, {:ok, updated_summary, updated_batch}}

            {:paused, updated_summary, updated_batch} ->
              {:halt, {:paused, updated_summary, updated_batch}}

            {:cancelled, updated_summary, updated_batch} ->
              {:halt, {:cancelled, updated_summary, updated_batch}}

            {:error, reason} ->
              {:halt, {:error, reason}}
          end

        {:paused, refreshed_batch} ->
          {:halt, {:paused, acc_summary, refreshed_batch}}

        {:cancelled, refreshed_batch} ->
          {:halt, {:cancelled, acc_summary, refreshed_batch}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp process_chunk(run, batch, bucket, chunk, chunk_index, creds, summary) do
    case ingest_chunk(run, batch, bucket, chunk, chunk_index, creds) do
      {:ok, metrics} ->
        metrics_with_index = Map.put(metrics, :chunk_index, chunk_index)
        apply_chunk_success(batch, chunk, metrics_with_index, summary)

      {:error, :no_common_prefix} ->
        process_chunk_as_single_entries(
          run,
          batch,
          bucket,
          chunk,
          chunk_index,
          creds,
          summary
        )

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_chunk_as_single_entries(run, batch, bucket, entries, chunk_index, creds, summary) do
    entries
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, summary, batch}, fn {entry, offset},
                                                   {:ok, acc_summary, acc_batch} ->
      case maybe_check_for_interruption(
             acc_batch,
             offset,
             @interruption_check_every_entries
           ) do
        {:ok, refreshed_batch} ->
          case ingest_chunk(
                 run,
                 refreshed_batch,
                 bucket,
                 [entry],
                 "#{chunk_index}-#{offset}",
                 creds
               ) do
            {:ok, metrics} ->
              metrics_with_index =
                Map.put(metrics, :chunk_index, "#{chunk_index}-#{offset}")

              case apply_chunk_success(
                     refreshed_batch,
                     [entry],
                     metrics_with_index,
                     acc_summary
                   ) do
                {:ok, updated_summary, updated_batch} ->
                  {:cont, {:ok, updated_summary, updated_batch}}

                {:error, reason} ->
                  {:halt, {:error, reason}}
              end

            {:error, reason} ->
              {:halt, {:error, reason}}
          end

        {:paused, refreshed_batch} ->
          {:halt, {:paused, acc_summary, refreshed_batch}}

        {:cancelled, refreshed_batch} ->
          {:halt, {:cancelled, acc_summary, refreshed_batch}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp apply_chunk_success(batch, chunk_entries, metrics, summary) do
    sequence =
      summary.metadata
      |> Map.get("chunk_sequence", summary.metadata |> Map.get("chunk_count", 0))
      |> parse_positive_integer(0)

    chunk_index = Integer.to_string(sequence + 1)
    metrics_with_sequence = Map.put(metrics, :chunk_index, chunk_index)
    chunk_record = chunk_log(metrics_with_sequence)

    with {:ok, entry} <- Inventory.upsert_chunk_log(batch, chunk_index, chunk_record) do
      updated_summary =
        summary
        |> accumulate_summary(chunk_entries, metrics_with_sequence)
        |> update_summary_metadata(sequence + 1)

      existing_metadata =
        batch.metadata
        |> ensure_map()

      merged_metadata =
        existing_metadata
        |> Map.merge(updated_summary.metadata)

      merged_summary = Map.put(updated_summary, :metadata, merged_metadata)

      update_attrs = %{
        processed_objects: merged_summary.processed_objects,
        metadata: merged_metadata
      }

      case Inventory.update_batch(batch, update_attrs) do
        {:ok, updated_batch} ->
          _ = Inventory.broadcast_chunk_log_update(entry, sequence + 1, merged_metadata)

          {:ok, merged_summary, updated_batch}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp accumulate_summary(summary, chunk_entries, metrics) do
    processed = summary.processed_objects + Enum.count(chunk_entries)

    rows_written = metrics[:rows_written] || metrics[:rows_read] || 0
    bytes_written = metrics[:bytes_written] || metrics[:bytes_read] || 0

    summary
    |> Map.put(:processed_objects, processed)
    |> Map.update(:rows_ingested, rows_written, &(&1 + rows_written))
    |> Map.update(:bytes_ingested, bytes_written, &(&1 + bytes_written))
  end

  defp chunk_log(metrics) do
    source_url = extract_source_url(metrics[:query])

    %{
      "chunk_index" => metrics |> Map.get(:chunk_index) |> to_chunk_index(),
      "query_id" => metrics[:query_id],
      "rows_read" => metrics[:rows_read],
      "rows_written" => metrics[:rows_written],
      "bytes_read" => metrics[:bytes_read],
      "bytes_written" => metrics[:bytes_written],
      "execution_time_ms" => metrics[:execution_time_ms],
      "source_url" => source_url,
      "dry_run" => metrics[:dry_run] || false
    }
  end

  defp to_chunk_index(value) when is_binary(value) and value != "", do: value
  defp to_chunk_index(value) when is_integer(value), do: Integer.to_string(value)
  defp to_chunk_index(value) when is_float(value), do: Float.to_string(value)
  defp to_chunk_index(_), do: UUID.uuid4()

  defp update_summary_metadata(summary, new_sequence) do
    metadata =
      summary.metadata
      |> ensure_map()
      |> Map.put("chunk_sequence", new_sequence)
      |> Map.put("chunk_count", new_sequence)

    Map.put(summary, :metadata, metadata)
  end

  defp extract_source_url(nil), do: nil

  defp extract_source_url(query) when is_binary(query) do
    case Regex.run(~r/FROM\s+s3\('([^']+)'/, query, capture: :all_but_first) do
      [url | _] -> url
      _ -> nil
    end
  end

  defp extract_source_url(_), do: nil

  defp maybe_check_for_interruption(batch, counter, frequency)
       when is_integer(counter) and is_integer(frequency) and frequency > 0 do
    if counter == 1 or rem(counter, frequency) == 0 do
      check_for_interruption(batch)
    else
      {:ok, batch}
    end
  end

  defp ingest_chunk(
         %InventoryRun{dry_run: true} = run,
         _batch,
         _bucket,
         _entries,
         chunk_index,
         _creds
       ) do
    {:ok,
     %{
       query_id: "dry-run-#{run.id}-#{chunk_index}",
       rows_read: 0,
       rows_written: 0,
       bytes_read: 0,
       bytes_written: 0,
       execution_time_ms: 0,
       dry_run: true,
       query: nil
     }}
  end

  defp ingest_chunk(run, batch, bucket, entries, chunk_index, creds) do
    keys = Enum.map(entries, & &1.key)

    with {:ok, pattern} <- build_pattern(keys),
         {:ok, metrics} <- run_chunk_insert(run, batch, bucket, pattern, chunk_index, creds) do
      {:ok, metrics}
    else
      {:error, :no_common_prefix} -> {:error, :no_common_prefix}
      {:error, reason} -> {:error, reason}
    end
  end

  defp run_chunk_insert(run, batch, bucket, pattern, chunk_index, creds) do
    s3_pattern = "s3://#{bucket}/#{pattern}"

    temp_run = %BackfillRun{
      target_table: run.target_table,
      s3_pattern: s3_pattern,
      format: run.format,
      clickhouse_settings: run.clickhouse_settings
    }

    query = QueryBuilder.insert_sql(temp_run, creds)
    query_id = chunk_query_id(batch, chunk_index)
    options = build_query_options(run, query_id)

    case ClickhouseAnalytics.execute_query(
           query,
           "inventory batch #{batch.id} chunk #{chunk_index}",
           options
         ) do
      {:ok, response} ->
        with {:ok, status} <- fetch_query_status(query_id) do
          case status[:status] do
            :failed ->
              {:error, status[:error] || "chunk query failed"}

            _ ->
              {:ok,
               %{
                 query_id: query_id,
                 rows_read: status[:rows_read],
                 rows_written: status[:rows_written],
                 bytes_read: status[:bytes_read],
                 bytes_written: status[:bytes_written],
                 execution_time_ms: Map.get(response, :execution_time_ms),
                 query: query
               }}
          end
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_pattern([single]) when is_binary(single), do: {:ok, single}

  defp build_pattern(keys) do
    keys = Enum.filter(keys, &is_binary/1)

    case longest_common_prefix(keys) do
      "" ->
        {:error, :no_common_prefix}

      prefix ->
        directory_prefix = truncate_to_directory(prefix)

        if directory_prefix == "" do
          {:error, :no_common_prefix}
        else
          suffixes =
            keys
            |> Enum.map(&String.replace_prefix(&1, directory_prefix, ""))
            |> Enum.uniq()

          if Enum.all?(suffixes, &(&1 == "")) do
            {:ok, directory_prefix}
          else
            {:ok, directory_prefix <> "{" <> Enum.join(suffixes, ",") <> "}"}
          end
        end
    end
  end

  defp longest_common_prefix([]), do: ""

  defp longest_common_prefix([first | rest]) do
    Enum.reduce(rest, first, fn string, acc -> common_prefix(acc, string) end)
  end

  defp common_prefix(<<>>, _), do: ""
  defp common_prefix(_, <<>>), do: ""

  defp common_prefix(str1, str2) do
    limit = min(byte_size(str1), byte_size(str2))

    Enum.reduce_while(0..(limit - 1), "", fn idx, acc ->
      <<c1::binary-size(1)>> = binary_part(str1, idx, 1)
      <<c2::binary-size(1)>> = binary_part(str2, idx, 1)

      if c1 == c2 do
        {:cont, acc <> c1}
      else
        {:halt, acc}
      end
    end)
  end

  defp truncate_to_directory(prefix) do
    parts = String.split(prefix, "/", trim: false)

    case parts do
      [] ->
        ""

      [single] ->
        if String.ends_with?(single, "/"), do: single, else: ""

      _ ->
        dir =
          parts
          |> Enum.drop(-1)
          |> Enum.join("/")

        if dir == "", do: "", else: dir <> "/"
    end
  end

  defp determine_chunk_size(%InventoryRun{} = run) do
    metadata = ensure_map(run.metadata)

    configured =
      metadata["batch_chunk_size"] ||
        metadata[:batch_chunk_size] ||
        Application.get_env(:oli, :clickhouse_inventory, %{})[:batch_chunk_size]

    parse_positive_integer(configured, 25)
  end

  defp determine_manifest_page_size(%InventoryRun{} = run, chunk_size) do
    metadata = ensure_map(run.metadata)
    manifest_meta = Map.get(metadata, "manifest", %{})

    configured =
      metadata["manifest_page_size"] ||
        metadata[:manifest_page_size] ||
        fetch_manifest_value(manifest_meta, [
          "manifest_page_size",
          :manifest_page_size,
          "page_size",
          :page_size
        ])

    default_size = default_manifest_page_size(chunk_size)
    parse_positive_integer(configured, default_size)
  end

  defp default_manifest_page_size(chunk_size) when is_integer(chunk_size) and chunk_size > 0 do
    max(chunk_size * 20, 1_000)
  end

  defp default_manifest_page_size(_), do: 1_000

  defp parse_positive_integer(value, _default) when is_integer(value) and value > 0, do: value

  defp parse_positive_integer(value, default) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {int, _} when int > 0 -> int
      _ -> default
    end
  end

  defp parse_positive_integer(_value, default), do: default

  defp chunk_query_id(batch, chunk_index) do
    "torus_inventory_batch_#{batch.id}_#{chunk_index}_#{UUID.uuid4()}"
  end

  defp build_query_options(run, query_id) do
    headers = [{"X-ClickHouse-Query-Id", query_id}]

    params =
      run.options
      |> ensure_map()
      |> Enum.reduce(%{"wait_end_of_query" => "1", "query_id" => query_id}, fn {key, value},
                                                                               acc ->
        Map.put(acc, to_string(key), normalize_param_value(value))
      end)

    [headers: headers, query_params: params]
  end

  defp normalize_param_value(value) when is_boolean(value), do: if(value, do: "1", else: "0")
  defp normalize_param_value(value) when is_integer(value), do: Integer.to_string(value)

  defp normalize_param_value(value) when is_float(value),
    do: :erlang.float_to_binary(value, [:compact])

  defp normalize_param_value(value) when is_binary(value), do: value
  defp normalize_param_value(value), do: to_string(value)

  defp fetch_query_status(query_id), do: poll_query_status(query_id, 0)

  defp poll_query_status(_query_id, attempt) when attempt >= @status_poll_attempts do
    {:ok, %{status: :unknown}}
  end

  defp poll_query_status(query_id, attempt) do
    case ClickhouseAnalytics.query_status(query_id) do
      {:ok, %{status: status} = info} when status in [:completed, :failed] ->
        {:ok, info}

      {:ok, _} ->
        Process.sleep(@status_poll_interval_ms)
        poll_query_status(query_id, attempt + 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp update_run_progress(%InventoryRun{} = run) do
    run = Repo.preload(run, :batches)

    total = length(run.batches)
    completed = Enum.count(run.batches, &(&1.status == :completed))
    failed = Enum.count(run.batches, &(&1.status == :failed))
    running = Enum.count(run.batches, &(&1.status == :running))

    progress = %{
      "total_batches" => total,
      "completed_batches" => completed,
      "failed_batches" => failed,
      "running_batches" => running,
      "percent" => percent(completed, total)
    }

    metadata =
      run.metadata
      |> ensure_map()
      |> Map.put("progress", progress)

    case Inventory.update_run(run, %{metadata: metadata}) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp percent(_completed, 0), do: 0.0
  defp percent(completed, total), do: completed / total * 100.0

  defp parquet_select_sql(
         %InventoryRun{} = run,
         %InventoryBatch{} = batch,
         %{} = creds,
         opts
       ) do
    {url, escaped_access_key, escaped_secret_key, session_clause} =
      parquet_s3_components(run, batch, creds)

    clauses =
      [
        "SELECT bucket, key",
        "FROM s3('#{url}', '#{escaped_access_key}', '#{escaped_secret_key}', 'Parquet')",
        session_clause,
        "ORDER BY bucket, key",
        build_limit_clause(opts)
      ]
      |> Enum.reject(&(&1 == ""))

    Enum.join(clauses, "\n")
  end

  defp parquet_count_sql(%InventoryRun{} = run, %InventoryBatch{} = batch, %{} = creds) do
    {url, escaped_access_key, escaped_secret_key, session_clause} =
      parquet_s3_components(run, batch, creds)

    clauses =
      [
        "SELECT count() AS object_count",
        "FROM s3('#{url}', '#{escaped_access_key}', '#{escaped_secret_key}', 'Parquet')",
        session_clause
      ]
      |> Enum.reject(&(&1 == ""))

    Enum.join(clauses, "\n")
  end

  defp parquet_s3_components(%InventoryRun{} = run, %InventoryBatch{} = batch, %{} = creds) do
    key = batch.parquet_key |> to_string() |> String.trim_leading("/")
    url = parquet_manifest_url(run, key) |> escape_single_quotes()

    access_key =
      Map.get(creds, :access_key_id) ||
        Map.get(creds, "access_key_id") ||
        ""

    secret_key =
      Map.get(creds, :secret_access_key) ||
        Map.get(creds, "secret_access_key") ||
        ""

    escaped_access_key = escape_single_quotes(access_key)
    escaped_secret_key = escape_single_quotes(secret_key)
    session_clause = parquet_settings_clause(creds)

    {url, escaped_access_key, escaped_secret_key, session_clause}
  end

  defp parquet_manifest_url(%InventoryRun{} = run, key) do
    manifest_meta =
      run.metadata
      |> ensure_map()
      |> Map.get("manifest", %{})

    scheme =
      manifest_meta
      |> fetch_manifest_value(["scheme", :scheme])
      |> safe_manifest_scheme()
      |> Kernel.||("https")

    host =
      manifest_meta
      |> fetch_manifest_value(["host", :host])
      |> safe_manifest_host()

    port =
      manifest_meta
      |> fetch_manifest_value(["port", :port])
      |> normalize_port()

    default_host = "#{run.manifest_bucket}.s3.amazonaws.com"
    port_part = format_port(port)

    cond do
      is_nil(host) ->
        "#{scheme}://#{default_host}/#{key}"

      String.contains?(host, run.manifest_bucket) ->
        "#{scheme}://#{host}#{port_part}/#{key}"

      true ->
        "#{scheme}://#{host}#{port_part}/#{run.manifest_bucket}/#{key}"
    end
  end

  defp format_port(nil), do: ""
  defp format_port(port) when is_integer(port) and port > 0, do: ":#{port}"
  defp format_port(_), do: ""

  defp parquet_settings_clause(%{} = creds) do
    case normalize_credential(Map.get(creds, :session_token) || Map.get(creds, "session_token")) do
      nil -> ""
      token -> "SETTINGS s3_session_token='#{escape_single_quotes(token)}'"
    end
  end

  defp build_limit_clause(opts) do
    limit = sanitize_positive_integer(Keyword.get(opts, :limit))
    offset = sanitize_non_negative_integer(Keyword.get(opts, :offset))

    cond do
      is_nil(limit) ->
        ""

      offset in [nil, 0] ->
        "LIMIT #{limit}"

      true ->
        "LIMIT #{limit} OFFSET #{offset}"
    end
  end

  defp sanitize_positive_integer(value) do
    case parse_positive_integer(value, nil) do
      int when is_integer(int) and int > 0 -> int
      _ -> nil
    end
  end

  defp sanitize_non_negative_integer(value) when is_integer(value) and value >= 0, do: value

  defp sanitize_non_negative_integer(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {int, _} when int >= 0 -> int
      _ -> nil
    end
  end

  defp sanitize_non_negative_integer(_), do: nil

  defp fetch_chunk_progress(%InventoryBatch{} = batch) do
    metadata = ensure_map(batch.metadata)

    metadata
    |> Map.get("chunk_count", 0)
    |> parse_positive_integer(0)
  end

  defp fetch_chunk_sequence(%InventoryBatch{} = batch) do
    metadata = ensure_map(batch.metadata)

    progress =
      metadata
      |> Map.get("chunk_count", 0)
      |> parse_positive_integer(0)

    metadata
    |> Map.get("chunk_sequence", progress)
    |> parse_positive_integer(progress)
  end

  defp escape_single_quotes(value) do
    value
    |> to_string()
    |> String.replace("'", "\\'")
  end

  defp filter_entries_by_date_range(entries, nil, _run), do: {entries, 0}

  defp filter_entries_by_date_range(entries, range, %InventoryRun{} = run) do
    {kept, dropped} =
      Enum.split_with(entries, fn entry ->
        Inventory.entry_in_date_range?(entry, range)
      end)

    dropped_count = length(dropped)

    if dropped_count > 0 do
      Logger.debug(
        "Filtered #{dropped_count} manifest entries outside configured date range for run #{run.id}"
      )
    end

    {kept, dropped_count}
  end

  defp valid_entry?(%{bucket: bucket, key: key}) when is_binary(bucket) and is_binary(key),
    do: true

  defp valid_entry?(_), do: false

  defp fetch_value(map, keys) do
    Enum.find_value(keys, fn key ->
      case map do
        %{} -> Map.get(map, key)
        _ -> nil
      end
    end)
  end

  defp check_for_interruption(%InventoryBatch{id: batch_id}) do
    case Repo.get(InventoryBatch, batch_id) do
      nil ->
        {:error, :missing_batch}

      %InventoryBatch{} = refreshed ->
        metadata = ensure_map(refreshed.metadata)

        cond do
          refreshed.status == :cancelled ->
            {:cancelled, refreshed}

          refreshed.status == :paused ->
            {:paused, refreshed}

          truthy?(Map.get(metadata, "pause_requested")) ->
            {:paused, refreshed}

          true ->
            {:ok, refreshed}
        end
    end
  end

  defp truthy?(value) when value in [true, "true", "1", 1, "on", "yes", "YES"], do: true
  defp truthy?(_), do: false

  defp ensure_map(nil), do: %{}
  defp ensure_map(map) when is_map(map), do: map
  defp ensure_map(_), do: %{}

  defp inventory_credentials(%InventoryRun{} = _run) do
    config = Application.get_env(:oli, :clickhouse_inventory, []) |> Enum.into(%{})

    access = Map.get(config, :manifest_access_key_id)
    secret = Map.get(config, :manifest_secret_access_key)
    session = Map.get(config, :manifest_session_token)

    access = normalize_credential(access)
    secret = normalize_credential(secret)
    session = normalize_credential(session)

    case {access, secret} do
      {nil, _} ->
        {:error, "manifest access key id not configured"}

      {_, nil} ->
        {:error, "manifest secret access key not configured"}

      {access_key, secret_key} ->
        creds =
          %{access_key_id: access_key, secret_access_key: secret_key}
          |> maybe_put_session_token(session)

        {:ok, creds}
    end
  end

  defp maybe_put_session_token(creds, nil), do: Map.drop(creds, [:session_token])
  defp maybe_put_session_token(creds, token), do: Map.put(creds, :session_token, token)

  defp fetch_manifest_value(map, keys) do
    Enum.find_value(keys, fn key ->
      case map do
        %{} -> Map.get(map, key)
        _ -> nil
      end
    end)
  end

  defp normalize_host(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_host(value) when is_atom(value), do: normalize_host(Atom.to_string(value))
  defp normalize_host(_), do: nil

  defp normalize_scheme(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      trimmed -> String.replace_trailing(trimmed, "://", "")
    end
  end

  defp normalize_scheme(value) when is_atom(value), do: normalize_scheme(Atom.to_string(value))
  defp normalize_scheme(_), do: nil

  defp normalize_port(value) when is_integer(value) and value > 0, do: value

  defp normalize_port(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {int, _} when int > 0 -> int
      _ -> nil
    end
  end

  defp normalize_port(_), do: nil

  defp safe_manifest_scheme(nil), do: nil

  defp safe_manifest_scheme(value) when is_binary(value) do
    case normalize_scheme(value) do
      "https" -> "https"
      _ -> nil
    end
  end

  defp safe_manifest_scheme(value) when is_atom(value) do
    safe_manifest_scheme(Atom.to_string(value))
  end

  defp safe_manifest_scheme(_), do: nil

  defp safe_manifest_host(nil), do: nil

  defp safe_manifest_host(value) do
    host = normalize_host(value)

    cond do
      is_nil(host) -> nil
      host == "s3.amazonaws.com" -> host
      String.ends_with?(host, ".s3.amazonaws.com") -> host
      Regex.match?(~r/^s3[.-][a-z0-9-]+\.amazonaws\.com$/, host) -> host
      true -> nil
    end
  end

  defp normalize_credential(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" ->
        nil

      trimmed ->
        case String.downcase(trimmed) do
          "nil" -> nil
          "null" -> nil
          "none" -> nil
          _ -> trimmed
        end
    end
  end

  defp normalize_credential(value) when is_atom(value),
    do: normalize_credential(Atom.to_string(value))

  defp normalize_credential(_), do: nil

  defp handle_failure(run, batch, reason) do
    message = format_error(reason)

    case Inventory.transition_batch(batch, :failed, %{error: message}) do
      {:ok, _} ->
        :ok

      {:error, error} ->
        Logger.error(
          "Failed to transition inventory batch #{batch.id} to failed: #{inspect(error)}"
        )
    end

    Inventory.recompute_run_aggregates(run)
    Inventory.transition_run(run, :failed, %{error: message})

    {:error, message}
  end

  defp format_error({:error, reason}), do: format_error(reason)
  defp format_error(%Ecto.Changeset{} = changeset), do: inspect(changeset)
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
