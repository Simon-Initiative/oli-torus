defmodule Oli.Analytics.Backfill.InventoryTest do
  use Oli.DataCase, async: true
  use Oban.Testing, repo: Oli.Repo

  alias Oli.Analytics.Backfill.{Inventory, InventoryBatch, InventoryRun}
  alias Oli.Repo

  describe "maybe_enqueue_pending_batches/1" do
    test "queues up to configured simultaneous limit" do
      Oban.Testing.reset()

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
      Oban.Testing.reset()

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
end
