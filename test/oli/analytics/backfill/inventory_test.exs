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
end
