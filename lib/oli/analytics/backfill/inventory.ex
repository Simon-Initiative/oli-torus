defmodule Oli.Analytics.Backfill.Inventory do
  @moduledoc """
  Context module for orchestrating ClickHouse backfills that consume Amazon S3 Inventory manifests.
  """

  import Ecto.Query, only: [from: 2]

  alias Ecto.Multi
  alias Oli.Analytics.Backfill
  alias Oli.Analytics.Backfill.InventoryRun
  alias Oli.Analytics.Backfill.InventoryBatch
  alias Oli.Analytics.Backfill.InventoryChunkLog
  alias Oli.Analytics.Backfill.Notifier
  alias Oli.Accounts.Author
  alias Phoenix.PubSub
  alias Oli.Repo
  require Logger
  alias Oban
  @chunk_logs_topic "clickhouse_chunk_logs"

  @type config :: %{
          optional(:manifest_bucket) => String.t(),
          optional(:manifest_prefix) => String.t(),
          optional(:manifest_suffix) => String.t(),
          optional(:directory_time_suffix) => String.t(),
          optional(:manifest_base_url) => String.t(),
          optional(:target_table) => String.t(),
          optional(:format) => String.t(),
          optional(:clickhouse_settings) => map(),
          optional(:options) => map(),
          optional(:batch_chunk_size) => pos_integer(),
          optional(:manifest_page_size) => pos_integer(),
          optional(:max_simultaneous_batches) => pos_integer(),
          optional(:max_batch_retries) => pos_integer()
        }

  @doc """
  Schedules a new inventory driven backfill run.
  """
  @spec schedule_run(map(), Author.t() | nil) :: {:ok, InventoryRun.t()} | {:error, term()}
  def schedule_run(attrs, initiated_by \\ nil) do
    attrs
    |> normalize_attrs()
    |> build_run_attrs(initiated_by)
    |> case do
      {:ok, run_attrs} -> persist_run_and_enqueue(run_attrs)
      {:error, reason} -> {:error, reason}
    end
  end

  defp inventory_config do
    Application.get_env(:oli, :clickhouse_inventory, %{}) |> Enum.into(%{})
  end

  defp inventory_config_value(key, default \\ nil) do
    inventory_config()
    |> Map.get(key, default)
  end

  defp default_manifest_suffix do
    inventory_config_value(:manifest_suffix, "manifest.json")
  end

  defp default_directory_suffix do
    inventory_config_value(:directory_time_suffix, "T01-00Z")
  end

  defp default_batch_chunk_size do
    inventory_config_value(:batch_chunk_size, 25)
  end

  defp default_manifest_page_size do
    inventory_config_value(:manifest_page_size, 1_000)
  end

  defp default_max_simultaneous_batches do
    inventory_config_value(:max_simultaneous_batches, 1)
  end

  defp default_max_batch_retries do
    inventory_config_value(:max_batch_retries, 1)
  end

  @doc """
  Fetch a run with associated batches ordered by sequence.
  """
  @spec get_run!(pos_integer()) :: InventoryRun.t()
  def get_run!(id) do
    Repo.get!(InventoryRun, id)
    |> Repo.preload([
      :initiated_by,
      batches: from(b in InventoryBatch, order_by: [asc: b.sequence])
    ])
  end

  @doc """
  List recent inventory runs ordered by insertion date descending.
  """
  @spec list_runs(keyword()) :: [InventoryRun.t()]
  def list_runs(opts \\ []) do
    limit = Keyword.get(opts, :limit)

    query =
      from run in InventoryRun,
        order_by: [desc: run.inserted_at],
        preload: [
          :initiated_by,
          batches: ^from(b in InventoryBatch, order_by: [asc: b.sequence])
        ]

    query = if is_integer(limit), do: from(run in query, limit: ^limit), else: query
    Repo.all(query)
  end

  @doc """
  Fetch a specific inventory batch with its parent run.
  """
  @spec get_batch!(pos_integer()) :: InventoryBatch.t()
  def get_batch!(id) do
    Repo.get!(InventoryBatch, id)
    |> Repo.preload(:run)
  end

  @doc """
  Recalculate and persist aggregate counters for the provided run.
  """
  @spec recompute_run_aggregates(InventoryRun.t()) :: {:ok, InventoryRun.t()} | {:error, term()}
  def recompute_run_aggregates(%InventoryRun{} = run) do
    run =
      run
      |> reload_run_record()
      |> Repo.preload(:batches)

    {completed, failed, running, pending} =
      Enum.reduce(run.batches, {0, 0, 0, 0}, fn batch, {comp, fail, runn, pend} ->
        case batch.status do
          :completed -> {comp + 1, fail, runn, pend}
          :failed -> {comp, fail + 1, runn, pend}
          :running -> {comp, fail, runn + 1, pend}
          :queued -> {comp, fail, runn, pend + 1}
          :pending -> {comp, fail, runn, pend + 1}
          :paused -> {comp, fail, runn, pend + 1}
          :cancelled -> {comp, fail, runn, pend}
        end
      end)

    total = length(run.batches)

    attrs = %{
      total_batches: total,
      completed_batches: completed,
      failed_batches: failed,
      running_batches: running,
      pending_batches: pending,
      rows_ingested: sum_field(run.batches, & &1.rows_ingested),
      bytes_ingested: sum_field(run.batches, & &1.bytes_ingested)
    }

    status = derive_run_status(run.status, total, completed, failed, running, pending)
    attrs = maybe_put_status(attrs, status)

    attrs =
      case status do
        :completed -> Map.put(attrs, :finished_at, run.finished_at || DateTime.utc_now())
        :failed -> Map.put(attrs, :finished_at, run.finished_at || DateTime.utc_now())
        :running -> Map.put(attrs, :started_at, run.started_at || DateTime.utc_now())
        :preparing -> Map.put(attrs, :started_at, run.started_at || DateTime.utc_now())
        _ -> attrs
      end

    run
    |> InventoryRun.changeset(attrs)
    |> Repo.update()
    |> notify(:inventory_run)
  end

  @doc """
  Transition a run to the provided status, applying optional attribute overrides.
  """
  @spec transition_run(InventoryRun.t(), InventoryRun.status(), map()) ::
          {:ok, InventoryRun.t()} | {:error, term()}
  def transition_run(%InventoryRun{} = run, status, attrs \\ %{}) do
    attrs =
      attrs
      |> Map.put(:status, status)
      |> maybe_put_run_timestamps(run, status)

    run
    |> InventoryRun.changeset(attrs)
    |> Repo.update()
    |> notify(:inventory_run)
  end

  @doc """
  Update a run without changing status semantics.
  """
  @spec update_run(InventoryRun.t(), map()) :: {:ok, InventoryRun.t()} | {:error, term()}
  def update_run(%InventoryRun{} = run, attrs) do
    run
    |> InventoryRun.changeset(attrs)
    |> Repo.update()
    |> notify(:inventory_run)
  end

  @doc """
  Transition a batch to the provided status, updating timestamps and attempts bookkeeping.
  """
  @spec transition_batch(InventoryBatch.t(), InventoryBatch.status(), map()) ::
          {:ok, InventoryBatch.t()} | {:error, term()}
  def transition_batch(%InventoryBatch{} = batch, status, attrs \\ %{}) do
    attrs =
      attrs
      |> Map.put(:status, status)
      |> maybe_put_batch_attempts(batch, status)
      |> maybe_put_batch_timestamps(batch, status)

    batch
    |> InventoryBatch.changeset(attrs)
    |> Repo.update()
    |> notify(:inventory_batch)
  end

  @doc """
  Update a batch with arbitrary attributes.
  """
  @spec update_batch(InventoryBatch.t(), map()) :: {:ok, InventoryBatch.t()} | {:error, term()}
  def update_batch(%InventoryBatch{} = batch, attrs) do
    batch
    |> InventoryBatch.changeset(attrs)
    |> Repo.update()
    |> notify(:inventory_batch)
  end

  @doc """
  Replace any existing batches for the run with the provided file manifests.
  """
  @spec prepare_batches(InventoryRun.t(), [map()]) ::
          {:ok, [InventoryBatch.t()]} | {:error, term()}
  def prepare_batches(%InventoryRun{} = run, files) when is_list(files) do
    multi =
      Multi.new()
      |> Multi.delete_all(:remove_existing, from(b in InventoryBatch, where: b.run_id == ^run.id))

    max_batch_retries = max_batch_retry_limit(run)

    multi =
      files
      |> Enum.with_index(1)
      |> Enum.reduce(multi, fn {file, index}, acc ->
        metadata =
          %{}
          |> maybe_put_metadata("size", file_size(file))
          |> maybe_put_metadata(
            "checksum",
            fetch_manifest_value(file, ["MD5checksum", :MD5checksum])
          )
          |> Map.put("dry_run", run.dry_run)
          |> Map.put_new("chunk_count", 0)
          |> Map.put_new("chunk_sequence", 0)
          |> Map.put_new("max_batch_retries", max_batch_retries)

        attrs = %{
          run_id: run.id,
          sequence: index,
          parquet_key: fetch_manifest_value(file, ["key", :key]),
          metadata: metadata
        }

        Multi.insert(
          acc,
          {:batch, index},
          InventoryBatch.creation_changeset(%InventoryBatch{}, attrs)
        )
      end)

    case Repo.transaction(multi) do
      {:ok, results} ->
        batches =
          results
          |> Enum.flat_map(fn
            {{:batch, _index}, %InventoryBatch{} = batch} -> [batch]
            _ -> []
          end)

        {:ok, batches}
        |> notify(:inventory_batch, %{action: :prepared})

      {:error, {:batch, _index}, reason, _changes} ->
        {:error, reason}

      {:error, _step, reason, _changes} ->
        {:error, reason}
    end
  end

  @doc """
  Enqueue a single batch for processing.
  """
  @spec enqueue_batch(InventoryBatch.t()) :: {:ok, InventoryBatch.t()} | {:error, term()}
  def enqueue_batch(%InventoryBatch{} = batch) do
    module = batch_worker_module()
    args = %{"batch_id" => batch.id}
    max_attempts = batch_max_attempts(batch)

    job_changeset =
      module.new(args,
        max_attempts: max_attempts,
        replace: [:scheduled_at, :queue, :worker]
      )

    case Oban.insert(job_changeset) do
      {:ok, job} ->
        metadata =
          batch.metadata
          |> ensure_map()
          |> Map.put("last_job_id", job.id)

        status =
          case job.state do
            :executing -> :running
            _ -> :queued
          end

        transition_batch(batch, status, %{metadata: metadata})

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetch chunk logs for the given batch using offset-based pagination.
  When `:include_total` is true the total count of logs for the batch is returned.
  Optional `:direction` values:
    * `:latest` — returns the last `limit` entries adjusting the offset automatically.
    * `:previous` / `:refresh` / `:next` — uses the provided offset.
  """
  @spec fetch_chunk_logs(pos_integer(), keyword()) :: %{
          entries: [InventoryChunkLog.t()],
          total: non_neg_integer | nil,
          offset: non_neg_integer
        }
  def fetch_chunk_logs(batch_id, opts \\ []) when is_integer(batch_id) do
    limit =
      opts
      |> Keyword.get(:limit, 100)
      |> clamp_limit()

    offset_param =
      opts
      |> Keyword.get(:offset, 0)
      |> max(0)

    include_total = Keyword.get(opts, :include_total, false)

    direction =
      opts
      |> Keyword.get(:direction, :forward)
      |> normalize_chunk_log_direction()

    base_query =
      from log in InventoryChunkLog,
        where: log.batch_id == ^batch_id

    total =
      cond do
        include_total -> Repo.aggregate(base_query, :count)
        direction == :latest -> Repo.aggregate(base_query, :count)
        true -> nil
      end

    offset =
      case {direction, total} do
        {:latest, count} when is_integer(count) ->
          max(count - limit, 0)

        _ ->
          offset_param
      end

    query =
      from log in base_query,
        order_by: [asc: log.inserted_at, asc: log.id],
        limit: ^limit,
        offset: ^offset

    entries = Repo.all(query)

    total =
      cond do
        is_integer(total) -> total
        include_total -> Repo.aggregate(base_query, :count)
        true -> nil
      end

    %{entries: entries, total: total, offset: offset}
  end

  @doc """
  Upsert (insert or replace) a chunk log entry for the specified batch.
  """
  @spec upsert_chunk_log(InventoryBatch.t() | pos_integer(), String.t(), map()) ::
          {:ok, InventoryChunkLog.t()} | {:error, term()}
  def upsert_chunk_log(%InventoryBatch{id: batch_id}, chunk_index, metrics),
    do: upsert_chunk_log(batch_id, chunk_index, metrics)

  def upsert_chunk_log(batch_id, chunk_index, metrics) when is_integer(batch_id) do
    timestamp = DateTime.utc_now()

    %InventoryChunkLog{}
    |> InventoryChunkLog.changeset(%{
      batch_id: batch_id,
      chunk_index: chunk_index,
      metrics: metrics
    })
    |> Repo.insert(
      on_conflict: [set: [metrics: metrics, updated_at: timestamp]],
      conflict_target: [:batch_id, :chunk_index]
    )
  end

  @doc """
  Delete all chunk logs associated with the provided batch.
  """
  @spec delete_chunk_logs_for_batch(InventoryBatch.t() | pos_integer()) :: :ok
  def delete_chunk_logs_for_batch(%InventoryBatch{id: batch_id}),
    do: delete_chunk_logs_for_batch(batch_id)

  def delete_chunk_logs_for_batch(batch_id) when is_integer(batch_id) do
    from(log in InventoryChunkLog, where: log.batch_id == ^batch_id)
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Format chunk log entries into transport-friendly maps.
  """
  @spec format_chunk_logs([InventoryChunkLog.t()], non_neg_integer()) :: [map()]
  def format_chunk_logs(entries, offset \\ 0) when is_list(entries) and offset >= 0 do
    entries
    |> Enum.with_index(offset + 1)
    |> Enum.map(&format_chunk_log_entry/1)
  end

  @doc """
  Compute the PubSub topic used by chunk log channels for a given batch.
  """
  @spec chunk_logs_topic(pos_integer()) :: String.t()
  def chunk_logs_topic(batch_id) when is_integer(batch_id) do
    "#{@chunk_logs_topic}:#{batch_id}"
  end

  @doc """
  Broadcast a chunk log update to subscribers.
  """
  @spec broadcast_chunk_log_update(InventoryChunkLog.t(), pos_integer(), map()) :: map()
  def broadcast_chunk_log_update(%InventoryChunkLog{} = entry, ordinal, metadata \\ %{})
      when is_integer(ordinal) and ordinal >= 1 do
    logs = format_chunk_logs([entry], max(ordinal - 1, 0))

    total =
      metadata
      |> ensure_map()
      |> fetch_first(["chunk_count", :chunk_count])
      |> parse_optional_number()
      |> case do
        nil -> ordinal
        value when is_integer(value) and value >= ordinal -> value
        value when is_integer(value) -> ordinal
        _ -> ordinal
      end

    payload = %{
      batch_id: entry.batch_id,
      log: hd(logs),
      ordinal: ordinal,
      total: total
    }

    PubSub.broadcast(Oli.PubSub, chunk_logs_topic(entry.batch_id), {:chunk_log_appended, payload})
    payload
  end

  defp format_chunk_log_entry({%InventoryChunkLog{} = entry, ordinal}) do
    metrics = ensure_map(entry.metrics)

    rows_written = fetch_numeric_metric(metrics, ["rows_written", :rows_written])
    rows_read = fetch_numeric_metric(metrics, ["rows_read", :rows_read])
    bytes_written = fetch_numeric_metric(metrics, ["bytes_written", :bytes_written])
    bytes_read = fetch_numeric_metric(metrics, ["bytes_read", :bytes_read])

    %{
      id: entry.id,
      ordinal: ordinal,
      chunk_index: entry.chunk_index || Integer.to_string(ordinal),
      query_id: fetch_metric(metrics, ["query_id", :query_id]),
      rows_written: rows_written,
      rows_read: rows_read,
      rows: rows_written || rows_read,
      bytes_written: bytes_written,
      bytes_read: bytes_read,
      bytes: bytes_written || bytes_read,
      execution_time_ms: fetch_numeric_metric(metrics, ["execution_time_ms", :execution_time_ms]),
      source_url: fetch_metric(metrics, ["source_url", :source_url]),
      dry_run: truthy?(fetch_metric(metrics, ["dry_run", :dry_run])),
      inserted_at:
        case entry.inserted_at do
          %DateTime{} = dt -> DateTime.to_iso8601(dt)
          _ -> nil
        end
    }
  end

  defp normalize_chunk_log_direction(:latest), do: :latest
  defp normalize_chunk_log_direction("latest"), do: :latest
  defp normalize_chunk_log_direction(:previous), do: :previous
  defp normalize_chunk_log_direction("previous"), do: :previous
  defp normalize_chunk_log_direction(:prev), do: :previous
  defp normalize_chunk_log_direction("prev"), do: :previous
  defp normalize_chunk_log_direction(:refresh), do: :refresh
  defp normalize_chunk_log_direction("refresh"), do: :refresh
  defp normalize_chunk_log_direction(_), do: :forward

  defp batch_max_attempts(%InventoryBatch{} = batch) do
    default = fetch_run_retry_limit(batch)

    batch.metadata
    |> ensure_map()
    |> fetch_first(["max_batch_retries", :max_batch_retries])
    |> parse_positive_integer(default)
  end

  defp fetch_run_retry_limit(%InventoryBatch{run: %InventoryRun{} = run}) do
    max_batch_retry_limit(run)
  end

  defp fetch_run_retry_limit(%InventoryBatch{run_id: run_id}) when is_integer(run_id) do
    case Repo.get(InventoryRun, run_id) do
      nil -> default_max_batch_retries()
      run -> max_batch_retry_limit(run)
    end
  end

  defp fetch_run_retry_limit(_), do: default_max_batch_retries()

  @doc """
  Reset and requeue a failed batch for another attempt.
  """
  @spec retry_batch(InventoryBatch.t()) :: {:ok, InventoryBatch.t()} | {:error, term()}
  def retry_batch(%InventoryBatch{} = batch) do
    reset_metadata =
      batch.metadata
      |> ensure_map()
      |> Map.put("chunk_count", 0)
      |> Map.put("chunk_sequence", 0)

    reset_attrs = %{
      error: nil,
      processed_objects: 0,
      rows_ingested: nil,
      bytes_ingested: nil,
      started_at: nil,
      finished_at: nil,
      metadata: reset_metadata
    }

    _ = delete_chunk_logs_for_batch(batch.id)

    with {:ok, batch} <- transition_batch(batch, :pending, reset_attrs),
         batch <- Repo.preload(batch, :run),
         :ok <- maybe_enqueue_pending_batches(batch.run) do
      _ = maybe_recompute_run(batch.run)

      reloaded_batch =
        InventoryBatch
        |> Repo.get!(batch.id)
        |> Repo.preload(:run)

      {:ok, reloaded_batch}
      |> notify(:inventory_batch, %{action: :retried})
    end
  end

  @doc """
  Pause an active run and request all outstanding batches to pause.
  """
  @spec pause_run(InventoryRun.t()) :: {:ok, InventoryRun.t()} | {:error, term()}
  def pause_run(%InventoryRun{} = run) do
    run = Repo.preload(run, :batches)

    cond do
      run.status in [:completed, :failed, :cancelled] ->
        {:error, :not_pausable}

      run.status == :paused ->
        {:ok, run}

      true ->
        metadata =
          run.metadata
          |> ensure_map()
          |> Map.put("pause_requested", true)
          |> Map.put("pause_requested_at", DateTime.utc_now())

        attrs = %{metadata: metadata}

        with {:ok, paused_run} <- transition_run(run, :paused, attrs),
             :ok <- pause_run_batches(paused_run.batches),
             {:ok, final_run} <- maybe_recompute_run(paused_run) do
          {:ok, Repo.preload(final_run, :batches)}
        end
    end
  end

  @doc """
  Resume a paused run and requeue eligible batches.
  """
  @spec resume_run(InventoryRun.t()) :: {:ok, InventoryRun.t()} | {:error, term()}
  def resume_run(%InventoryRun{} = run) do
    run = Repo.preload(run, :batches)
    metadata = ensure_map(run.metadata)

    cond do
      run.status != :paused and not truthy?(Map.get(metadata, "pause_requested")) ->
        {:error, :not_paused}

      true ->
        updated_metadata =
          metadata
          |> Map.delete("pause_requested")
          |> Map.delete("pause_requested_at")
          |> Map.put("resumed_at", DateTime.utc_now())

        attrs = %{metadata: updated_metadata}

        with {:ok, resumed_run} <- transition_run(run, :running, attrs),
             :ok <- resume_run_batches(resumed_run.batches),
             {:ok, rebalanced_run} <- maybe_recompute_run(resumed_run),
             :ok <- maybe_enqueue_pending_batches(rebalanced_run) do
          {:ok, Repo.preload(rebalanced_run, :batches)}
        end
    end
  end

  @doc """
  Request that a batch pause processing. Running batches mark themselves for pause,
  while queued or pending batches transition immediately to `:paused`.
  """
  @spec pause_batch(InventoryBatch.t()) :: {:ok, InventoryBatch.t()} | {:error, term()}
  def pause_batch(%InventoryBatch{} = batch) do
    batch = Repo.preload(batch, :run)
    run = batch.run

    cond do
      batch.status in [:completed, :failed, :cancelled] ->
        {:error, :not_pausable}

      batch.status == :paused ->
        {:ok, batch}

      batch.status in [:pending, :queued] ->
        metadata = ensure_map(batch.metadata)
        metadata = Map.put(metadata, "pause_requested", false)

        _ =
          if batch.status == :queued do
            cancel_batch_job(batch)
          end

        with {:ok, updated_batch} <- transition_batch(batch, :paused, %{metadata: metadata}),
             {:ok, _} <- maybe_recompute_run(run) do
          {:ok, %{updated_batch | run: run}}
          |> notify(:inventory_batch, %{action: :paused})
        end

      true ->
        metadata =
          batch.metadata
          |> ensure_map()
          |> Map.put("pause_requested", true)
          |> Map.put("pause_requested_at", DateTime.utc_now())

        with {:ok, updated_batch} <- update_batch(batch, %{metadata: metadata}) do
          {:ok, %{updated_batch | run: run}}
          |> notify(:inventory_batch, %{action: :pause_requested})
        end
    end
  end

  @doc """
  Resume a paused batch by returning it to the pending queue.
  """
  @spec resume_batch(InventoryBatch.t()) :: {:ok, InventoryBatch.t()} | {:error, term()}
  def resume_batch(%InventoryBatch{} = batch) do
    batch = Repo.preload(batch, :run)
    run = batch.run

    if batch.status != :paused do
      {:error, :not_paused}
    else
      metadata =
        batch.metadata
        |> ensure_map()
        |> Map.delete("pause_requested")
        |> Map.delete("pause_requested_at")
        |> Map.put("resumed_at", DateTime.utc_now())

      with {:ok, updated_batch} <- transition_batch(batch, :pending, %{metadata: metadata}),
           :ok <- maybe_enqueue_pending_batches(run),
           {:ok, _} <- maybe_recompute_run(run) do
        reloaded =
          InventoryBatch
          |> Repo.get!(updated_batch.id)
          |> Repo.preload(:run)

        {:ok, reloaded}
        |> notify(:inventory_batch, %{action: :resumed})
      end
    end
  end

  @doc """
  Cancel an in-flight inventory batch and prevent further processing.
  """
  @spec cancel_batch(InventoryBatch.t(), keyword()) ::
          {:ok, InventoryBatch.t()} | {:error, term()}
  def cancel_batch(%InventoryBatch{} = batch, opts \\ []) do
    recompute? = Keyword.get(opts, :recompute, true)

    batch = Repo.preload(batch, :run)

    if cancellable_batch_status?(batch.status) do
      _ = cancel_batch_job(batch)

      attrs = %{
        error: nil,
        metadata: put_cancel_metadata(batch.metadata)
      }

      with {:ok, updated_batch} <- transition_batch(batch, :cancelled, attrs),
           {:ok, _} <- maybe_recompute_run(batch.run, recompute?) do
        {:ok, %{updated_batch | run: batch.run}}
        |> notify(:inventory_batch, %{action: :cancelled})
      end
    else
      {:error, :not_cancellable}
    end
  end

  @doc """
  Cancel an inventory run along with any outstanding batches and queued jobs.
  """
  @spec cancel_run(InventoryRun.t()) :: {:ok, InventoryRun.t()} | {:error, term()}
  def cancel_run(%InventoryRun{} = run) do
    run = Repo.preload(run, :batches)

    if terminal_run_status?(run.status) do
      {:error, :not_cancellable}
    else
      Repo.transaction(fn ->
        _ = cancel_orchestrator_job(run)

        Enum.each(run.batches, fn batch ->
          if cancellable_batch_status?(batch.status) do
            case cancel_batch(batch, recompute: false) do
              {:ok, _} -> :ok
              {:error, :not_cancellable} -> :ok
              {:error, reason} -> Repo.rollback(reason)
            end
          end
        end)

        attrs = %{
          error: nil,
          metadata: put_cancel_metadata(run.metadata)
        }

        with {:ok, run} <- transition_run(run, :cancelled, attrs),
             {:ok, run} <- recompute_run_aggregates(run) do
          run
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
      |> case do
        {:ok, run} ->
          {:ok, run}
          |> notify(:inventory_run, %{action: :cancelled})

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Delete an inventory run that has already completed or been stopped.
  """
  @spec delete_run(InventoryRun.t()) :: {:ok, InventoryRun.t()} | {:error, term()}
  def delete_run(%InventoryRun{} = run) do
    if terminal_run_status?(run.status) do
      Repo.delete(run)
      |> notify(:inventory_run, %{action: :deleted})
    else
      {:error, :not_deletable}
    end
  end

  defp sum_field(batches, fun) do
    Enum.reduce(batches, 0, fn batch, acc ->
      case fun.(batch) do
        value when is_integer(value) -> acc + value
        value when is_float(value) -> acc + trunc(value)
        _ -> acc
      end
    end)
  end

  defp maybe_recompute_run(%InventoryRun{} = run) do
    case recompute_run_aggregates(run) do
      {:ok, _} = result -> result
      {:error, _} = error -> error
    end
  end

  defp maybe_recompute_run(_), do: {:ok, nil}

  defp maybe_recompute_run(%InventoryRun{} = run, true), do: maybe_recompute_run(run)
  defp maybe_recompute_run(%InventoryRun{} = run, false), do: {:ok, run}
  defp maybe_recompute_run(_, _), do: {:ok, nil}

  defp parse_positive_integer(value, _default)
       when is_integer(value) and value > 0,
       do: value

  defp parse_positive_integer(value, default) when is_binary(value) do
    value
    |> String.trim()
    |> Integer.parse()
    |> case do
      {int, _} when int > 0 -> int
      _ -> default
    end
  end

  defp parse_positive_integer(_value, default), do: default

  @doc """
  Determine the maximum number of inventory batches that may run simultaneously for a run.
  """
  @spec max_simultaneous_batches(InventoryRun.t()) :: pos_integer()
  def max_simultaneous_batches(%InventoryRun{} = run) do
    default =
      inventory_config()
      |> Map.get(:max_simultaneous_batches, default_max_simultaneous_batches())
      |> parse_positive_integer(default_max_simultaneous_batches())

    run.metadata
    |> ensure_map()
    |> fetch_first(["max_simultaneous_batches", :max_simultaneous_batches])
    |> parse_positive_integer(default)
  end

  @doc """
  Determine the maximum automatic retry attempts for batches within a run.
  """
  @spec max_batch_retry_limit(InventoryRun.t()) :: pos_integer()
  def max_batch_retry_limit(%InventoryRun{} = run) do
    default =
      inventory_config()
      |> Map.get(:max_batch_retries, default_max_batch_retries())
      |> parse_positive_integer(default_max_batch_retries())

    run.metadata
    |> ensure_map()
    |> fetch_first(["max_batch_retries", :max_batch_retries])
    |> parse_positive_integer(default)
  end

  @doc """
  Enqueue pending batches for a run up to the configured simultaneous limit.
  """
  @spec maybe_enqueue_pending_batches(InventoryRun.t()) :: :ok | {:error, term()}
  def maybe_enqueue_pending_batches(%InventoryRun{} = run) do
    metadata = ensure_map(run.metadata)

    cond do
      run.status == :paused ->
        :ok

      truthy?(Map.get(metadata, "pause_requested")) ->
        :ok

      true ->
        limit = max_simultaneous_batches(run)

        limit =
          case limit do
            int when is_integer(int) and int > 0 -> int
            _ -> default_max_simultaneous_batches()
          end

        active_query =
          from b in InventoryBatch,
            where: b.run_id == ^run.id and b.status in [:queued, :running]

        active = Repo.aggregate(active_query, :count, :id)

        needed = limit - active

        if needed <= 0 do
          :ok
        else
          pending_query =
            from b in InventoryBatch,
              where: b.run_id == ^run.id and b.status == :pending,
              order_by: [asc: b.sequence],
              limit: ^needed

          pending_query
          |> Repo.all()
          |> Enum.reduce_while(:ok, fn batch, :ok ->
            case enqueue_batch(batch) do
              {:ok, _} -> {:cont, :ok}
              {:error, reason} -> {:halt, {:error, reason}}
            end
          end)
          |> case do
            :ok -> :ok
            {:error, reason} -> {:error, reason}
          end
        end
    end
  end

  defp cancellable_batch_status?(status), do: status in [:pending, :queued, :running, :paused]
  defp terminal_run_status?(status), do: status in [:completed, :failed, :cancelled]

  defp pause_run_batches(batches) do
    batches
    |> Enum.filter(&(&1.status in [:pending, :queued, :running]))
    |> Enum.reduce_while(:ok, fn batch, :ok ->
      case pause_batch(batch) do
        {:ok, _} -> {:cont, :ok}
        {:error, :not_pausable} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp resume_run_batches(batches) do
    batches
    |> Enum.filter(&(&1.status == :paused))
    |> Enum.reduce_while(:ok, fn batch, :ok ->
      case resume_batch(batch) do
        {:ok, _} -> {:cont, :ok}
        {:error, :not_paused} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp cancel_orchestrator_job(%InventoryRun{} = run) do
    run.metadata
    |> ensure_map()
    |> fetch_first(["orchestrator_job_id", :orchestrator_job_id])
    |> cancel_job()
  end

  defp cancel_batch_job(%InventoryBatch{} = batch) do
    batch.metadata
    |> ensure_map()
    |> fetch_first(["last_job_id", :last_job_id])
    |> cancel_job()
  end

  defp cancel_job(nil), do: :ok

  defp cancel_job(job_id) when is_binary(job_id) do
    case Integer.parse(job_id) do
      {int, _} -> cancel_job(int)
      :error -> :ok
    end
  end

  defp cancel_job(job_id) when is_integer(job_id) do
    case Oban.cancel_job(job_id) do
      {:ok, _job} ->
        :ok

      :ok ->
        :ok

      {:error, :not_found} ->
        :ok

      {:error, reason} ->
        Logger.warning("Unable to cancel Oban job #{job_id}: #{inspect(reason)}")
        :ok
    end
  end

  defp cancel_job(_), do: :ok

  defp put_cancel_metadata(metadata) do
    metadata
    |> ensure_map()
    |> Map.put("cancelled_at", DateTime.utc_now())
  end

  defp fetch_first(map, keys) do
    Enum.find_value(keys, fn key ->
      case map do
        %{} -> Map.get(map, key)
        _ -> nil
      end
    end)
  end

  defp reload_run_record(%InventoryRun{id: id} = run) do
    case Repo.get(InventoryRun, id) do
      nil -> run
      reloaded -> reloaded
    end
  end

  defp maybe_put_status(attrs, nil), do: attrs
  defp maybe_put_status(attrs, status), do: Map.put(attrs, :status, status)

  defp derive_run_status(current_status, 0, _completed, _failed, _running, _pending) do
    current_status
  end

  defp derive_run_status(current, total, completed, failed, running, pending) do
    cond do
      current == :cancelled -> :cancelled
      current == :paused -> :paused
      failed > 0 -> :failed
      completed == total and total > 0 -> :completed
      running > 0 -> :running
      current == :preparing -> :preparing
      pending > 0 -> :pending
      true -> current
    end
  end

  defp persist_run_and_enqueue(run_attrs) do
    multi =
      Multi.new()
      |> Multi.insert(:run, InventoryRun.creation_changeset(%InventoryRun{}, run_attrs))
      |> Multi.run(:job, fn _repo, %{run: run} ->
        args = %{"run_id" => run.id}

        case orchestrator_worker().new(args) |> Oban.insert() do
          {:ok, job} -> {:ok, job}
          {:error, reason} -> {:error, reason}
        end
      end)
      |> Multi.update(:annotated_run, fn %{run: run, job: job} ->
        metadata =
          run.metadata
          |> ensure_map()
          |> Map.put("orchestrator_job_id", job.id)

        InventoryRun.changeset(run, %{metadata: metadata})
      end)

    case Repo.transaction(multi) do
      {:ok, %{annotated_run: run}} ->
        {:ok, Repo.preload(run, :initiated_by)}
        |> notify(:inventory_run)

      {:error, :run, changeset, _} ->
        {:error, changeset}

      {:error, :job, reason, %{run: run}} ->
        Repo.delete(run)
        {:error, reason}

      {:error, :annotated_run, changeset, %{run: run}} ->
        Repo.delete(run)
        {:error, changeset}

      {:error, _step, reason, _} ->
        {:error, reason}
    end
  end

  defp notify(result, source, metadata \\ %{})

  defp notify({:ok, %InventoryRun{} = run} = result, :inventory_run, metadata) do
    meta =
      metadata
      |> Map.new()
      |> Map.put_new(:run_id, run.id)
      |> Map.put_new("run_id", run.id)

    _ = Notifier.broadcast(:inventory_run, meta)
    result
  end

  defp notify({:ok, %InventoryBatch{} = batch} = result, :inventory_batch, metadata) do
    meta =
      metadata
      |> Map.new()
      |> Map.put_new(:batch_id, batch.id)
      |> Map.put_new("batch_id", batch.id)
      |> Map.put_new(:run_id, batch.run_id)
      |> Map.put_new("run_id", batch.run_id)

    _ = Notifier.broadcast(:inventory_batch, meta)
    result
  end

  defp notify({:ok, _value} = result, source, metadata) do
    _ = Notifier.broadcast(source, metadata)
    result
  end

  defp notify(result, _source, _metadata), do: result

  defp build_run_attrs(attrs, initiated_by) do
    with {:ok, date} <- fetch_date(attrs),
         {:ok, config} <- resolved_config(attrs),
         {:ok, prefix} <- inventory_prefix(date, attrs, config),
         manifest_suffix <- config[:manifest_suffix] || default_manifest_suffix(),
         {:ok, manifest_url} <- manifest_url(config, prefix, manifest_suffix) do
      manifest_key = cleaned_join([prefix, manifest_suffix])
      dry_run = truthy?(fetch_value(attrs, :dry_run, false))

      max_simultaneous_default =
        config[:max_simultaneous_batches]
        |> parse_positive_integer(default_max_simultaneous_batches())

      max_retries_default =
        config[:max_batch_retries]
        |> parse_positive_integer(default_max_batch_retries())

      max_simultaneous =
        attrs
        |> fetch_value(:max_simultaneous_batches, max_simultaneous_default)
        |> parse_positive_integer(default_max_simultaneous_batches())

      max_batch_retries =
        attrs
        |> fetch_value(:max_batch_retries, max_retries_default)
        |> parse_positive_integer(default_max_batch_retries())

      metadata =
        attrs
        |> fetch_value(:metadata, %{})
        |> ensure_map()
        |> Map.put_new("batch_chunk_size", config[:batch_chunk_size])
        |> Map.put_new("manifest_page_size", config[:manifest_page_size])
        |> Map.put("max_simultaneous_batches", max_simultaneous)
        |> Map.put("max_batch_retries", max_batch_retries)
        |> Map.put(
          "manifest",
          %{
            "bucket" => config[:manifest_bucket],
            "prefix" => prefix,
            "url" => manifest_url,
            "key" => manifest_key
          }
          |> maybe_put_manifest_detail(
            "host",
            fetch_value(attrs, :manifest_host, config[:manifest_host])
          )
          |> maybe_put_manifest_detail(
            "scheme",
            fetch_value(attrs, :manifest_scheme, config[:manifest_scheme])
          )
          |> maybe_put_manifest_detail(
            "port",
            fetch_value(attrs, :manifest_port, config[:manifest_port])
          )
          |> maybe_put_manifest_credential(
            "access_key_id",
            fetch_value(attrs, :manifest_access_key_id, config[:manifest_access_key_id])
          )
          |> maybe_put_manifest_credential(
            "secret_access_key",
            fetch_value(attrs, :manifest_secret_access_key, config[:manifest_secret_access_key])
          )
          |> maybe_put_manifest_credential(
            "session_token",
            fetch_value(attrs, :manifest_session_token, config[:manifest_session_token])
          )
        )
        |> Map.put("dry_run", dry_run)

      run_attrs =
        attrs
        |> Map.put(:inventory_date, date)
        |> Map.put(:inventory_prefix, prefix)
        |> Map.put(:manifest_url, manifest_url)
        |> Map.put(:manifest_bucket, config[:manifest_bucket])
        |> Map.put(:target_table, fetch_value(attrs, :target_table, config[:target_table]))
        |> Map.put(:format, fetch_value(attrs, :format, config[:format]))
        |> Map.put(
          :clickhouse_settings,
          fetch_value(attrs, :clickhouse_settings, config[:clickhouse_settings] || %{})
        )
        |> Map.put(:options, fetch_value(attrs, :options, config[:options] || %{}))
        |> Map.put(:metadata, metadata)
        |> Map.put(:dry_run, dry_run)
        |> Map.put(:status, :pending)
        |> maybe_put_initiator(initiated_by)

      {:ok, run_attrs}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_date(%{inventory_date: %Date{} = date}), do: {:ok, date}
  defp fetch_date(%{"inventory_date" => value}), do: parse_date(value)
  defp fetch_date(%{inventory_date: value}), do: parse_date(value)
  defp fetch_date(_), do: {:error, "inventory_date is required"}

  defp parse_date(%Date{} = date), do: {:ok, date}

  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(String.trim(value)) do
      {:ok, date} -> {:ok, date}
      {:error, _} -> {:error, "invalid date"}
    end
  end

  defp parse_date(_), do: {:error, "invalid date"}

  defp inventory_prefix(date, attrs, config) do
    case Map.get(attrs, :inventory_prefix) || Map.get(attrs, "inventory_prefix") do
      nil ->
        suffix = config[:directory_time_suffix] || default_directory_suffix()
        prefix = cleaned_join([config[:manifest_prefix], Date.to_iso8601(date) <> suffix])
        {:ok, prefix}

      prefix when is_binary(prefix) ->
        {:ok, String.trim(prefix)}

      _ ->
        {:error, "invalid inventory prefix"}
    end
  end

  defp manifest_url(%{manifest_bucket: nil}, _prefix, _suffix),
    do: {:error, "manifest_bucket not configured"}

  defp manifest_url(config, prefix, suffix) do
    bucket = config[:manifest_bucket]
    base = config[:manifest_base_url] || "https://#{bucket}.s3.amazonaws.com"
    {:ok, cleaned_join([base, prefix, suffix])}
  end

  defp resolved_config(attrs) do
    env_config = inventory_config()
    attr_overrides = extract_config_overrides(attrs)

    config =
      default_config()
      |> Map.merge(env_config)
      |> Map.merge(attr_overrides)

    cond do
      is_nil(config[:manifest_bucket]) -> {:error, "manifest bucket not configured"}
      is_nil(config[:manifest_prefix]) -> {:error, "manifest prefix not configured"}
      true -> {:ok, config}
    end
  end

  defp extract_config_overrides(attrs) do
    Enum.reduce(attrs, %{}, fn
      {key, value}, acc when is_binary(key) ->
        key
        |> to_existing_atom_rescue()
        |> maybe_put_override(value, acc)

      {key, value}, acc when is_atom(key) ->
        maybe_put_override(key, value, acc)

      _other, acc ->
        acc
    end)
  end

  defp maybe_put_override(_key, nil, acc), do: acc

  defp maybe_put_override(key, value, acc)
       when key in [
              :manifest_bucket,
              :manifest_prefix,
              :manifest_suffix,
              :directory_time_suffix,
              :manifest_host,
              :manifest_scheme,
              :manifest_port,
              :manifest_access_key_id,
              :manifest_secret_access_key,
              :manifest_session_token,
              :manifest_base_url,
              :target_table,
              :format,
              :clickhouse_settings,
              :options,
              :batch_chunk_size,
              :manifest_page_size,
              :max_simultaneous_batches,
              :max_batch_retries
            ] do
    Map.put(acc, key, value)
  end

  defp maybe_put_override(_key, _value, acc), do: acc

  defp to_existing_atom_rescue(value) when is_atom(value), do: value

  defp to_existing_atom_rescue(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> nil
  end

  defp orchestrator_worker do
    Application.get_env(
      :oli,
      :inventory_orchestrator_worker,
      Oli.Analytics.Backfill.Inventory.OrchestratorWorker
    )
  end

  @doc false
  def batch_worker_module do
    Application.get_env(
      :oli,
      :inventory_batch_worker,
      Oli.Analytics.Backfill.Inventory.BatchWorker
    )
  end

  defp default_config do
    %{
      manifest_bucket: inventory_config_value(:manifest_bucket),
      manifest_prefix: inventory_config_value(:manifest_prefix),
      manifest_host: inventory_config_value(:manifest_host),
      manifest_scheme: inventory_config_value(:manifest_scheme),
      manifest_port: inventory_config_value(:manifest_port),
      manifest_access_key_id: inventory_config_value(:manifest_access_key_id),
      manifest_secret_access_key: inventory_config_value(:manifest_secret_access_key),
      manifest_session_token: inventory_config_value(:manifest_session_token),
      manifest_suffix: default_manifest_suffix(),
      directory_time_suffix: default_directory_suffix(),
      target_table: inventory_config_value(:target_table, Backfill.default_target_table()),
      format: inventory_config_value(:format, "JSONAsString"),
      clickhouse_settings: inventory_config_value(:clickhouse_settings, %{}),
      options: inventory_config_value(:options, %{}),
      batch_chunk_size: default_batch_chunk_size(),
      manifest_page_size: default_manifest_page_size(),
      max_simultaneous_batches: default_max_simultaneous_batches(),
      max_batch_retries: default_max_batch_retries()
    }
  end

  defp maybe_put_manifest_detail(manifest_map, _key, nil), do: manifest_map

  defp maybe_put_manifest_detail(manifest_map, key, value)
       when key in ["host", "scheme"] and is_binary(value) do
    trimmed =
      value
      |> String.trim()
      |> case do
        "" -> nil
        normalized -> normalized
      end

    case trimmed do
      nil -> manifest_map
      normalized -> Map.put(manifest_map, key, normalized)
    end
  end

  defp maybe_put_manifest_detail(manifest_map, "host", value) when is_atom(value) do
    maybe_put_manifest_detail(manifest_map, "host", Atom.to_string(value))
  end

  defp maybe_put_manifest_detail(manifest_map, "scheme", value) when is_atom(value) do
    maybe_put_manifest_detail(manifest_map, "scheme", Atom.to_string(value))
  end

  defp maybe_put_manifest_detail(manifest_map, "port", value)
       when is_integer(value) and value > 0 do
    Map.put(manifest_map, "port", value)
  end

  defp maybe_put_manifest_detail(manifest_map, "port", value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {int, _} when int > 0 -> Map.put(manifest_map, "port", int)
      _ -> manifest_map
    end
  end

  defp maybe_put_manifest_detail(manifest_map, _key, _value), do: manifest_map

  defp maybe_put_manifest_credential(manifest_map, _key, nil), do: manifest_map

  defp maybe_put_manifest_credential(manifest_map, key, value) when is_binary(value) do
    trimmed =
      value
      |> String.trim()
      |> case do
        "" -> nil
        normalized -> normalized
      end

    case cleaned_credential(trimmed) do
      nil -> manifest_map
      normalized -> Map.put(manifest_map, key, normalized)
    end
  end

  defp maybe_put_manifest_credential(manifest_map, key, value) when is_atom(value) do
    maybe_put_manifest_credential(manifest_map, key, Atom.to_string(value))
  end

  defp maybe_put_manifest_credential(manifest_map, _key, _value), do: manifest_map

  defp cleaned_credential(nil), do: nil

  defp cleaned_credential(value) do
    lowered = String.downcase(value)

    cond do
      lowered in ["nil", "null", "none"] -> nil
      true -> value
    end
  end

  defp normalize_attrs(attrs) when is_list(attrs), do: Enum.into(attrs, %{})
  defp normalize_attrs(%{} = attrs), do: attrs
  defp normalize_attrs(_), do: %{}

  defp maybe_put_initiator(attrs, %Author{id: author_id}),
    do: Map.put(attrs, :initiated_by_id, author_id)

  defp maybe_put_initiator(attrs, _), do: attrs

  defp fetch_value(map, key, default) do
    case fetch_raw(map, key) do
      {:ok, value} -> value
      :error -> default
    end
  end

  defp fetch_raw(map, key) do
    case Map.fetch(map, key) do
      {:ok, _} = result -> result
      :error -> Map.fetch(map, to_string(key))
    end
  end

  defp clamp_limit(limit) when is_integer(limit) and limit > 0 do
    min(limit, 500)
  end

  defp clamp_limit(_), do: 100

  defp ensure_map(nil), do: %{}
  defp ensure_map(map) when is_map(map), do: map
  defp ensure_map(_), do: %{}

  defp fetch_metric(map, keys, default \\ nil) when is_list(keys) do
    keys
    |> Enum.reduce_while(nil, fn key, _acc ->
      case map do
        %{} -> Map.get(map, key)
        _ -> nil
      end
      |> case do
        nil -> {:cont, nil}
        value -> {:halt, value}
      end
    end)
    |> case do
      nil -> default
      value -> value
    end
  end

  defp fetch_numeric_metric(map, keys) when is_list(keys) do
    map
    |> fetch_metric(keys)
    |> parse_optional_number()
  end

  defp parse_optional_number(value) when is_integer(value), do: value
  defp parse_optional_number(value) when is_float(value), do: trunc(value)

  defp parse_optional_number(value) when is_binary(value) do
    trimmed = String.trim(value)

    case Integer.parse(trimmed) do
      {int, _} ->
        int

      :error ->
        case Float.parse(trimmed) do
          {float, _} -> trunc(float)
          :error -> nil
        end
    end
  end

  defp parse_optional_number(_), do: nil

  defp truthy?(value) when value in [true, "true", "1", 1, "on", "yes", "TRUE", "Yes"],
    do: true

  defp truthy?(_), do: false

  defp maybe_put_run_timestamps(attrs, %InventoryRun{} = run, status) do
    attrs =
      if status in [:preparing, :running] do
        Map.put_new(attrs, :started_at, run.started_at || DateTime.utc_now())
      else
        attrs
      end

    if status in [:completed, :failed, :cancelled] do
      Map.put_new(attrs, :finished_at, run.finished_at || DateTime.utc_now())
    else
      attrs
    end
  end

  defp maybe_put_batch_attempts(attrs, %InventoryBatch{} = batch, status) do
    cond do
      status == :running ->
        attrs
        |> Map.put(:attempts, Map.get(attrs, :attempts, (batch.attempts || 0) + 1))
        |> Map.put(:last_attempt_at, Map.get(attrs, :last_attempt_at, DateTime.utc_now()))

      status == :queued ->
        attrs
        |> Map.put_new(:attempts, batch.attempts || 0)

      true ->
        attrs
        |> Map.put_new(:attempts, batch.attempts || 0)
    end
  end

  defp maybe_put_batch_timestamps(attrs, %InventoryBatch{} = batch, status) do
    attrs =
      if status == :running do
        Map.put_new(attrs, :started_at, batch.started_at || DateTime.utc_now())
      else
        attrs
      end

    if status in [:completed, :failed, :cancelled] do
      Map.put_new(attrs, :finished_at, batch.finished_at || DateTime.utc_now())
    else
      attrs
    end
  end

  defp maybe_put_metadata(map, _key, nil), do: map
  defp maybe_put_metadata(map, key, value), do: Map.put(map, key, value)

  defp file_size(file) do
    fetch_manifest_value(file, ["size", :size])
  end

  defp fetch_manifest_value(file, keys) do
    Enum.find_value(keys, fn key ->
      case file do
        %{} -> Map.get(file, key)
        _ -> nil
      end
    end)
  end

  defp cleaned_join(parts) do
    parts
    |> Enum.map(&String.trim_trailing(to_string(&1), "/"))
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("/")
  end
end
