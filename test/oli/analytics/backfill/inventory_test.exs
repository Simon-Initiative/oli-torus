defmodule Oli.Analytics.Backfill.InventoryTest do
  use Oli.DataCase, async: true
  use Oban.Testing, repo: Oli.Repo

  import Ecto.Query

  alias Oli.Analytics.Backfill.{Inventory, InventoryBatch, InventoryChunkLog, InventoryRun}
  alias Oli.Repo

  describe "maybe_enqueue_pending_batches/1" do
    test "queues up to configured simultaneous limit" do
      run =
        %InventoryRun{
          inventory_date: ~D[2024-07-01],
          inventory_prefix: "inventory/prefix/2024-07-01",
          manifest_url: "https://example.com/manifest.json",
          manifest_bucket: "test-bucket",
          target_table: "analytics.raw_events",
          format: "JSONAsString",
          status: :pending,
          metadata: %{
            "max_simultaneous_batches" => 1,
            "max_batch_retries" => 1
          }
        }
        |> Repo.insert!()

      batches =
        for seq <- 1..3 do
          %InventoryBatch{
            run_id: run.id,
            sequence: seq,
            parquet_key: "inventory/#{seq}.parquet",
            status: :pending
          }
          |> Repo.insert!()
        end

      assert :ok = Inventory.maybe_enqueue_pending_batches(run)

      assert [%Oban.Job{args: %{"batch_id" => batch_id}, max_attempts: 1}] =
               all_enqueued(worker: Oli.Analytics.Backfill.Inventory.BatchWorker)

      queued_batch = Repo.get!(InventoryBatch, batch_id)
      assert queued_batch.status == :queued

      remaining =
        batches
        |> Enum.reject(&(&1.id == batch_id))
        |> Enum.map(&Repo.get!(InventoryBatch, &1.id))

      assert Enum.all?(remaining, &(&1.status == :pending))
    end

    test "respects higher limits and retry configuration" do
      run =
        %InventoryRun{
          inventory_date: ~D[2024-07-02],
          inventory_prefix: "inventory/prefix/2024-07-02",
          manifest_url: "https://example.com/manifest.json",
          manifest_bucket: "test-bucket",
          target_table: "analytics.raw_events",
          format: "JSONAsString",
          status: :pending,
          metadata: %{
            "max_simultaneous_batches" => 2,
            "max_batch_retries" => 3
          }
        }
        |> Repo.insert!()

      for seq <- 1..3 do
        %InventoryBatch{
          run_id: run.id,
          sequence: seq,
          parquet_key: "inventory/#{seq}.parquet",
          status: :pending
        }
        |> Repo.insert!()
      end

      assert :ok = Inventory.maybe_enqueue_pending_batches(run)

      jobs = all_enqueued(worker: Oli.Analytics.Backfill.Inventory.BatchWorker)
      assert length(jobs) == 2
      assert Enum.all?(jobs, &(&1.max_attempts == 3))
    end
  end

  describe "chunk log storage" do
    setup do
      run =
        %InventoryRun{
          inventory_date: ~D[2024-07-03],
          inventory_prefix: "inventory/prefix/2024-07-03",
          manifest_url: "https://example.com/manifest.json",
          manifest_bucket: "test-bucket",
          target_table: "analytics.raw_events",
          format: "JSONAsString",
          status: :pending,
          metadata: %{
            "max_simultaneous_batches" => 1,
            "max_batch_retries" => 1
          }
        }
        |> Repo.insert!()

      batch =
        %InventoryBatch{
          run_id: run.id,
          sequence: 1,
          parquet_key: "inventory/1.parquet",
          status: :failed,
          metadata: %{"chunk_count" => 0}
        }
        |> Repo.insert!()

      %{run: run, batch: batch}
    end

    test "upserts and fetches chunk logs in order", %{batch: batch} do
      metrics = %{
        "chunk_index" => "1",
        "rows_written" => 10,
        "bytes_written" => 100,
        "execution_time_ms" => 5
      }

      assert {:ok, %InventoryChunkLog{} = entry} =
               Inventory.upsert_chunk_log(batch, "1", metrics)

      assert entry.chunk_index == "1"

      updated_metrics = Map.put(metrics, "rows_written", 20)

      assert {:ok, %InventoryChunkLog{} = updated_entry} =
               Inventory.upsert_chunk_log(batch.id, "1", updated_metrics)

      assert updated_entry.metrics["rows_written"] == 20

      second_metrics = %{
        "chunk_index" => "2",
        "rows_written" => 30,
        "bytes_written" => 200
      }

      assert {:ok, _second} = Inventory.upsert_chunk_log(batch, "2", second_metrics)

      %{entries: entries, total: total} =
        Inventory.fetch_chunk_logs(batch.id, offset: 0, limit: 10, include_total: true)

      assert total == 2
      assert Enum.map(entries, & &1.chunk_index) == ["1", "2"]
      assert hd(entries).metrics["rows_written"] == 20
    end

    test "fetch_chunk_logs with latest direction returns recent entries", %{batch: batch} do
      for index <- 1..3 do
        chunk_index = Integer.to_string(index)
        metrics = %{"chunk_index" => chunk_index}
        {:ok, _} = Inventory.upsert_chunk_log(batch, chunk_index, metrics)
      end

      %{entries: entries, total: total, offset: offset} =
        Inventory.fetch_chunk_logs(batch.id,
          limit: 2,
          include_total: true,
          direction: :latest
        )

      assert total == 3
      assert offset == 1
      assert Enum.map(entries, & &1.chunk_index) == ["2", "3"]
    end

    test "format_chunk_logs turns entries into transport maps", %{batch: batch} do
      metrics = %{
        "chunk_index" => "1",
        "rows_written" => 5,
        "bytes_written" => 100,
        "source_url" => "s3://bucket/key"
      }

      {:ok, entry} = Inventory.upsert_chunk_log(batch, "1", metrics)

      formatted = Inventory.format_chunk_logs([entry], 0)

      assert [%{chunk_index: "1", rows_written: 5, bytes: 100, source_url: "s3://bucket/key"}] =
               formatted
    end

    test "broadcast_chunk_log_update publishes payload", %{batch: batch} do
      metrics = %{"chunk_index" => "1", "rows_written" => 5}
      {:ok, entry} = Inventory.upsert_chunk_log(batch, "1", metrics)

      Phoenix.PubSub.subscribe(Oli.PubSub, Inventory.chunk_logs_topic(batch.id))

      payload = Inventory.broadcast_chunk_log_update(entry, 1, %{"chunk_count" => 1})

      assert_receive {:chunk_log_appended, ^payload}
      assert payload.total == 1
      assert payload.log.chunk_index == "1"
    end

    test "deletes chunk logs for batch", %{batch: batch} do
      metrics = %{"chunk_index" => "1", "rows_written" => 5}
      {:ok, _} = Inventory.upsert_chunk_log(batch, "1", metrics)
      {:ok, _} = Inventory.upsert_chunk_log(batch, "2", Map.put(metrics, "chunk_index", "2"))

      assert Repo.aggregate(InventoryChunkLog, :count, :id) == 2

      :ok = Inventory.delete_chunk_logs_for_batch(batch.id)
      assert Repo.aggregate(InventoryChunkLog, :count, :id) == 0
    end

    test "retry_batch clears chunk logs and resets chunk_count", %{batch: batch} do
      metrics = %{"chunk_index" => "1", "rows_written" => 5}
      {:ok, _} = Inventory.upsert_chunk_log(batch, "1", metrics)
      {:ok, _} = Inventory.upsert_chunk_log(batch, "2", Map.put(metrics, "chunk_index", "2"))

      batch =
        batch
        |> InventoryBatch.changeset(%{metadata: %{"chunk_count" => 2}})
        |> Repo.update!()

      assert {:ok, %InventoryBatch{} = updated_batch} = Inventory.retry_batch(batch)

      batch_id = batch.id

      assert Repo.aggregate(
               from(log in InventoryChunkLog, where: log.batch_id == ^batch_id),
               :count,
               :id
             ) == 0

      updated = Repo.get!(InventoryBatch, updated_batch.id)
      assert updated.metadata["chunk_count"] == 0

      assert [%Oban.Job{args: %{"batch_id" => ^batch_id}}] =
               all_enqueued(worker: Oli.Analytics.Backfill.Inventory.BatchWorker)
    end
  end

  describe "date range filters" do
    test "extract_date_range parses metadata into utc datetimes" do
      metadata = %{
        "filters" => %{
          "date_range" => %{
            "start" => "2024-07-05T00:00:00Z",
            "end" => "2024-07-06T01:30:00Z"
          }
        }
      }

      assert {:ok, %{start: start_dt, end: end_dt}} = Inventory.extract_date_range(metadata)
      assert %DateTime{} = start_dt
      assert %DateTime{} = end_dt
      assert DateTime.to_iso8601(start_dt) == "2024-07-05T00:00:00Z"
      assert DateTime.to_iso8601(end_dt) == "2024-07-06T01:30:00Z"
    end

    test "entry_in_date_range? returns true only for entries inside the window" do
      {:ok, start_dt, _} = DateTime.from_iso8601("2024-07-05T00:00:00Z")
      {:ok, end_dt, _} = DateTime.from_iso8601("2024-07-06T00:00:00Z")
      range = %{start: start_dt, end: end_dt}

      inside_entry = %{
        bucket: "bucket",
        key: "section/1/xapi/2024-07-05T12-00-00Z_bundle.jsonl"
      }

      before_entry = %{
        bucket: "bucket",
        key: "section/1/xapi/2024-07-04T23-59-59Z_bundle.jsonl"
      }

      after_entry = %{
        bucket: "bucket",
        key: "section/1/xapi/2024-07-06T00-00-01Z_bundle.jsonl"
      }

      assert Inventory.entry_in_date_range?(inside_entry, range)
      refute Inventory.entry_in_date_range?(before_entry, range)
      refute Inventory.entry_in_date_range?(after_entry, range)
    end

    test "entry_in_date_range? ignores entries with unparsable keys" do
      range = %{start: nil, end: nil}
      entry = %{bucket: "bucket", key: "section/1/xapi/not_a_timestamp.jsonl"}

      assert Inventory.entry_in_date_range?(entry, range)
    end

    test "manifest_entry_timestamp parses hyphenated filenames" do
      entry = %{
        bucket: "bucket",
        key: "section/3501/attempt_evaluated/2025-04-04T17-24-38.860042Z_file.jsonl"
      }

      assert {:ok, datetime} = Inventory.manifest_entry_timestamp(entry)
      assert DateTime.to_iso8601(datetime) == "2025-04-04T17:24:38.860042Z"
    end

    test "skipped_objects aggregates batch metadata" do
      run =
        %InventoryRun{
          inventory_date: ~D[2024-07-07],
          inventory_prefix: "inventory/prefix/2024-07-07",
          manifest_url: "https://example.com/manifest.json",
          manifest_bucket: "test-bucket",
          target_table: "analytics.raw_events",
          format: "JSONAsString",
          status: :running
        }
        |> Repo.insert!()

      %InventoryBatch{
        run_id: run.id,
        sequence: 1,
        parquet_key: "inventory/1.parquet",
        status: :completed,
        metadata: %{"skipped_objects" => 3}
      }
      |> Repo.insert!()

      %InventoryBatch{
        run_id: run.id,
        sequence: 2,
        parquet_key: "inventory/2.parquet",
        status: :completed,
        metadata: %{"skipped_objects" => 4}
      }
      |> Repo.insert!()

      run = Repo.get!(InventoryRun, run.id) |> Repo.preload(:batches)

      assert Inventory.skipped_objects(run) == 7
    end
  end

  describe "pause and resume batch" do
    setup do
      run =
        %InventoryRun{
          inventory_date: ~D[2024-07-05],
          inventory_prefix: "inventory/prefix/2024-07-05",
          manifest_url: "https://example.com/manifest.json",
          manifest_bucket: "test-bucket",
          target_table: "analytics.raw_events",
          format: "JSONAsString",
          status: :running,
          metadata: %{
            "max_simultaneous_batches" => 1,
            "max_batch_retries" => 1
          }
        }
        |> Repo.insert!()

      %{run: run}
    end

    test "pause_batch moves pending batch to paused", %{run: run} do
      batch =
        %InventoryBatch{
          run_id: run.id,
          sequence: 1,
          parquet_key: "inventory/1.parquet",
          status: :pending,
          metadata: %{}
        }
        |> Repo.insert!()

      assert {:ok, %InventoryBatch{} = paused_batch} = Inventory.pause_batch(batch)
      assert paused_batch.status == :paused
      assert Map.get(paused_batch.metadata, "pause_requested") == false
    end

    test "pause_batch on running batch sets pause flag", %{run: run} do
      batch =
        %InventoryBatch{
          run_id: run.id,
          sequence: 1,
          parquet_key: "inventory/1.parquet",
          status: :running,
          metadata: %{}
        }
        |> Repo.insert!()

      assert {:ok, %InventoryBatch{} = paused} = Inventory.pause_batch(batch)
      assert paused.status == :running
      assert Map.get(paused.metadata, "pause_requested")
      assert Map.get(paused.metadata, "pause_requested_at")
    end

    test "resume_batch returns paused batch to pending", %{run: run} do
      batch =
        %InventoryBatch{
          run_id: run.id,
          sequence: 1,
          parquet_key: "inventory/1.parquet",
          status: :paused,
          metadata: %{"pause_requested" => false}
        }
        |> Repo.insert!()

      assert {:ok, %InventoryBatch{} = resumed} = Inventory.resume_batch(batch)
      assert resumed.status in [:pending, :queued]
      refute Map.has_key?(resumed.metadata, "pause_requested")
    end
  end

  describe "pause and resume run" do
    setup do
      run =
        %InventoryRun{
          inventory_date: ~D[2024-07-06],
          inventory_prefix: "inventory/prefix/2024-07-06",
          manifest_url: "https://example.com/manifest.json",
          manifest_bucket: "test-bucket",
          target_table: "analytics.raw_events",
          format: "JSONAsString",
          status: :running,
          metadata: %{}
        }
        |> Repo.insert!()

      pending_batch =
        %InventoryBatch{
          run_id: run.id,
          sequence: 1,
          parquet_key: "inventory/pending.parquet",
          status: :pending
        }
        |> Repo.insert!()

      running_batch =
        %InventoryBatch{
          run_id: run.id,
          sequence: 2,
          parquet_key: "inventory/running.parquet",
          status: :running,
          processed_objects: 5
        }
        |> Repo.insert!()

      {:ok,
       run: Repo.preload(run, :batches),
       pending_batch: pending_batch,
       running_batch: running_batch}
    end

    test "pause_run marks run and batches", %{
      run: run,
      pending_batch: pending_batch,
      running_batch: running_batch
    } do
      assert {:ok, paused_run} = Inventory.pause_run(run)
      assert paused_run.status == :paused
      assert paused_run.metadata["pause_requested"]

      paused_pending = Repo.get!(InventoryBatch, pending_batch.id)
      assert paused_pending.status == :paused

      paused_running = Repo.get!(InventoryBatch, running_batch.id)
      assert paused_running.status == :running
      assert paused_running.metadata["pause_requested"]
    end

    test "resume_run clears pause flags and resumes batches", %{run: run} do
      {:ok, paused_run} = Inventory.pause_run(run)

      {:ok, resumed_run} = Inventory.resume_run(paused_run)
      assert resumed_run.status in [:running, :pending]
      refute resumed_run.metadata["pause_requested"]

      resumed_batches =
        InventoryBatch
        |> where([b], b.run_id == ^resumed_run.id)
        |> Repo.all()

      assert Enum.any?(resumed_batches, &(&1.status in [:pending, :queued, :running]))

      assert Enum.all?(resumed_batches, fn batch ->
               metadata = batch.metadata || %{}
               is_nil(metadata["pause_requested"])
             end)
    end

    test "resume_run errors when run is not paused", %{run: run} do
      assert {:error, :not_paused} = Inventory.resume_run(run)
    end
  end
end
