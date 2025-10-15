defmodule Oli.Analytics.Backfill.Inventory.BatchWorker do
  @moduledoc """
  Processes a single parquet-described batch of JSONL objects and streams them into ClickHouse.
  """

  use Oban.Worker,
    queue: :clickhouse_inventory_batches,
    max_attempts: 5,
    unique: [fields: [:args, :worker], keys: [:batch_id], period: 300]

  require Logger

  alias Oli.Analytics.Backfill
  alias Oli.Analytics.Backfill.BackfillRun
  alias Oli.Analytics.Backfill.Inventory
  alias Oli.Analytics.Backfill.InventoryBatch
  alias Oli.Analytics.Backfill.InventoryRun
  alias Oli.Analytics.Backfill.QueryBuilder
  alias Oli.Analytics.ClickhouseAnalytics
  alias Oli.Repo

  @status_poll_attempts 12
  @status_poll_interval_ms 1_000

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
         {:ok, entries} <- fetch_parquet_entries(run, batch, creds),
         {:ok, batch} <- annotate_batch(batch, entries),
         {:ok, summary, batch} <- ingest_entries(run, batch, entries, creds),
         {:ok, batch} <- Inventory.transition_batch(batch, :completed, summary),
         {:ok, run} <- Inventory.recompute_run_aggregates(run),
         :ok <- update_run_progress(run),
         :ok <- Inventory.maybe_enqueue_pending_batches(run) do
      {:ok, batch}
    else
      {:error, reason} -> handle_failure(run, batch, reason)
    end
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

  defp fetch_parquet_entries(%InventoryRun{} = run, %InventoryBatch{} = batch, creds) do
    query = parquet_select_sql(run, batch, creds)

    case ClickhouseAnalytics.execute_query(query, "inventory parquet #{batch.id}") do
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

  defp annotate_batch(%InventoryBatch{} = batch, entries) do
    total = Enum.count(entries)

    metadata =
      batch.metadata
      |> ensure_map()
      |> Map.put("object_count", total)
      |> Map.put_new("chunks", [])

    Inventory.update_batch(batch, %{object_count: total, processed_objects: 0, metadata: metadata})
  end

  defp ingest_entries(%InventoryRun{} = run, %InventoryBatch{} = batch, [], _creds) do
    summary = %{
      processed_objects: 0,
      rows_ingested: 0,
      bytes_ingested: 0,
      metadata:
        batch.metadata
        |> ensure_map()
        |> Map.put("dry_run", run.dry_run)
    }

    {:ok, summary, batch}
  end

  defp ingest_entries(%InventoryRun{} = run, %InventoryBatch{} = batch, entries, creds) do
    chunk_size = determine_chunk_size(run)

    grouped_entries =
      entries
      |> Enum.filter(&valid_entry?/1)
      |> Enum.group_by(& &1.bucket)

    initial_summary = %{
      processed_objects: 0,
      rows_ingested: 0,
      bytes_ingested: 0,
      metadata:
        batch.metadata
        |> ensure_map()
        |> Map.put_new("chunks", [])
        |> Map.put("dry_run", run.dry_run)
    }

    Enum.reduce_while(grouped_entries, {:ok, initial_summary, batch}, fn {bucket, bucket_entries},
                                                                         {:ok, summary,
                                                                          batch_state} ->
      process_bucket(run, batch_state, bucket, bucket_entries, chunk_size, creds, summary)
    end)
  end

  defp process_bucket(run, batch, bucket, entries, chunk_size, creds, summary) do
    entries
    |> Enum.chunk_every(chunk_size, chunk_size, [])
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, summary, batch}, fn {chunk, index},
                                                   {:ok, acc_summary, acc_batch} ->
      case process_chunk(run, acc_batch, bucket, chunk, index, creds, acc_summary) do
        {:ok, updated_summary, updated_batch} -> {:cont, {:ok, updated_summary, updated_batch}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp process_chunk(run, batch, bucket, chunk, chunk_index, creds, summary) do
    case ingest_chunk(run, batch, bucket, chunk, chunk_index, creds) do
      {:ok, metrics} ->
        apply_chunk_success(batch, chunk, metrics, summary)

      {:error, :no_common_prefix} ->
        process_chunk_as_single_entries(run, batch, bucket, chunk, chunk_index, creds, summary)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_chunk_as_single_entries(run, batch, bucket, entries, chunk_index, creds, summary) do
    entries
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, summary, batch}, fn {entry, offset},
                                                   {:ok, acc_summary, acc_batch} ->
      case ingest_chunk(run, acc_batch, bucket, [entry], "#{chunk_index}-#{offset}", creds) do
        {:ok, metrics} ->
          case apply_chunk_success(acc_batch, [entry], metrics, acc_summary) do
            {:ok, updated_summary, updated_batch} ->
              {:cont, {:ok, updated_summary, updated_batch}}

            {:error, reason} ->
              {:halt, {:error, reason}}
          end

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp apply_chunk_success(batch, chunk_entries, metrics, summary) do
    updated_summary = accumulate_summary(summary, chunk_entries, metrics)

    update_attrs = %{
      processed_objects: updated_summary.processed_objects,
      metadata: updated_summary.metadata
    }

    case Inventory.update_batch(batch, update_attrs) do
      {:ok, updated_batch} -> {:ok, updated_summary, updated_batch}
      {:error, reason} -> {:error, reason}
    end
  end

  defp accumulate_summary(summary, chunk_entries, metrics) do
    processed = summary.processed_objects + Enum.count(chunk_entries)

    rows_written = metrics[:rows_written] || metrics[:rows_read] || 0
    bytes_written = metrics[:bytes_written] || metrics[:bytes_read] || 0

    chunk_record = chunk_log(metrics)

    metadata =
      summary.metadata
      |> Map.update("chunks", [chunk_record], &(&1 ++ [chunk_record]))

    summary
    |> Map.put(:processed_objects, processed)
    |> Map.update(:rows_ingested, rows_written, &(&1 + rows_written))
    |> Map.update(:bytes_ingested, bytes_written, &(&1 + bytes_written))
    |> Map.put(:metadata, metadata)
  end

  defp chunk_log(metrics) do
    source_url = extract_source_url(metrics[:query])

    %{
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

  defp extract_source_url(nil), do: nil

  defp extract_source_url(query) when is_binary(query) do
    case Regex.run(~r/FROM\s+s3\('([^']+)'/, query, capture: :all_but_first) do
      [url | _] -> url
      _ -> nil
    end
  end

  defp extract_source_url(_), do: nil

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

    metadata["batch_chunk_size"] ||
      metadata[:batch_chunk_size] ||
      Application.get_env(:oli, :clickhouse_inventory, %{})[:batch_chunk_size] ||
      25
      |> parse_positive_integer(25)
  end

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

  defp parquet_select_sql(%InventoryRun{} = run, %InventoryBatch{} = batch, %{} = creds) do
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

    """
    SELECT bucket, key
    FROM s3('#{url}', '#{escaped_access_key}', '#{escaped_secret_key}', 'Parquet')
    #{session_clause}
    """
  end

  defp parquet_manifest_url(%InventoryRun{} = run, key) do
    manifest_meta =
      run.metadata
      |> ensure_map()
      |> Map.get("manifest", %{})

    scheme =
      manifest_meta
      |> Map.get("scheme") ||
        Map.get(manifest_meta, :scheme)
        |> normalize_scheme()
        |> Kernel.||("https")

    host =
      manifest_meta
      |> Map.get("host") ||
        Map.get(manifest_meta, :host)
        |> normalize_host()

    port =
      manifest_meta
      |> Map.get("port") ||
        Map.get(manifest_meta, :port)
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

  defp escape_single_quotes(value) do
    value
    |> to_string()
    |> String.replace("'", "\\'")
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

  defp ensure_map(nil), do: %{}
  defp ensure_map(map) when is_map(map), do: map
  defp ensure_map(_), do: %{}

  defp inventory_credentials(%InventoryRun{} = run) do
    manifest_meta =
      run.metadata
      |> ensure_map()
      |> Map.get("manifest", %{})

    access = fetch_manifest_value(manifest_meta, ["access_key_id", :access_key_id])
    secret = fetch_manifest_value(manifest_meta, ["secret_access_key", :secret_access_key])
    session = fetch_manifest_value(manifest_meta, ["session_token", :session_token])

    access = normalize_credential(access)
    secret = normalize_credential(secret)
    session = normalize_credential(session)

    case {access, secret} do
      {nil, _} ->
        fallback_inventory_credentials()

      {_, nil} ->
        fallback_inventory_credentials()

      {access_key, secret_key} ->
        creds =
          %{access_key_id: access_key, secret_access_key: secret_key}
          |> maybe_put_session_token(session)

        {:ok, creds}
    end
  end

  defp fallback_inventory_credentials do
    case Backfill.aws_credentials() do
      {:ok, creds} ->
        session =
          normalize_credential(Map.get(creds, :session_token) || Map.get(creds, "session_token"))

        {:ok, maybe_put_session_token(creds, session)}

      {:error, reason} ->
        {:error, reason}
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
