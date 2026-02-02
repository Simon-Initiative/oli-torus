defmodule Oli.Analytics.InventoryTest do
  use Oli.DataCase, async: true

  alias Oli.Analytics.Backfill.{Inventory, InventoryBatch, InventoryRun}
  alias Oli.Repo

  describe "recompute_run_aggregates/1" do
    test "preserves completed status when recomputing from a stale struct" do
      attrs = %{
        inventory_date: ~D[2025-10-05],
        inventory_prefix: "torus-xapi-prod/2025-10-05T01-00Z",
        manifest_url: "https://example-bucket/manifest.json",
        manifest_bucket: "example-bucket",
        target_table: "analytics.raw_events",
        format: "JSONAsString",
        status: :preparing,
        dry_run: true,
        metadata: %{}
      }

      run =
        %InventoryRun{}
        |> InventoryRun.creation_changeset(attrs)
        |> Repo.insert!()

      stale_run = run

      assert {:ok, completed_run} = Inventory.transition_run(run, :completed)
      assert completed_run.status == :completed
      refute is_nil(completed_run.finished_at)

      assert {:ok, recomputed} = Inventory.recompute_run_aggregates(stale_run)
      assert recomputed.status == :completed
      assert Repo.get!(InventoryRun, run.id).status == :completed
    end
  end

  describe "cancel_batch/2" do
    test "transitions running batch to cancelled and recomputes aggregates" do
      run_attrs = %{
        inventory_date: ~D[2025-10-05],
        inventory_prefix: "torus-xapi-prod/2025-10-05T01-00Z",
        manifest_url: "https://example-bucket/manifest.json",
        manifest_bucket: "example-bucket",
        target_table: "analytics.raw_events",
        format: "JSONAsString",
        status: :running,
        metadata: %{}
      }

      run =
        %InventoryRun{}
        |> InventoryRun.creation_changeset(run_attrs)
        |> Repo.insert!()

      batch_attrs = %{
        run_id: run.id,
        sequence: 1,
        parquet_key: "inventory/2025-10-05/file.parquet",
        status: :running,
        object_count: 10,
        processed_objects: 4
      }

      batch =
        %InventoryBatch{}
        |> InventoryBatch.creation_changeset(batch_attrs)
        |> Repo.insert!()

      assert {:ok, cancelled_batch} = Inventory.cancel_batch(batch)
      assert cancelled_batch.status == :cancelled

      stored_batch = Repo.get!(InventoryBatch, batch.id)
      assert stored_batch.status == :cancelled
      assert stored_batch.metadata["cancelled_at"]

      stored_run = Repo.get!(InventoryRun, run.id)
      assert stored_run.status == :running
      assert stored_run.running_batches in [0, nil]
    end
  end

  describe "cancel_run/1" do
    test "cancels run and outstanding batches" do
      run_attrs = %{
        inventory_date: ~D[2025-10-05],
        inventory_prefix: "torus-xapi-prod/2025-10-05T01-00Z",
        manifest_url: "https://example-bucket/manifest.json",
        manifest_bucket: "example-bucket",
        target_table: "analytics.raw_events",
        format: "JSONAsString",
        status: :running,
        metadata: %{}
      }

      run =
        %InventoryRun{}
        |> InventoryRun.creation_changeset(run_attrs)
        |> Repo.insert!()

      running_batch =
        %InventoryBatch{}
        |> InventoryBatch.creation_changeset(%{
          run_id: run.id,
          sequence: 1,
          parquet_key: "inventory/2025-10-05/running.parquet",
          status: :running,
          object_count: 12
        })
        |> Repo.insert!()

      failed_batch =
        %InventoryBatch{}
        |> InventoryBatch.creation_changeset(%{
          run_id: run.id,
          sequence: 2,
          parquet_key: "inventory/2025-10-05/failed.parquet",
          status: :failed,
          object_count: 8
        })
        |> Repo.insert!()

      assert {:ok, cancelled_run} = Inventory.cancel_run(run)
      assert cancelled_run.status == :cancelled

      reloaded_run = Repo.get!(InventoryRun, run.id)
      assert reloaded_run.status == :cancelled
      refute is_nil(reloaded_run.finished_at)
      assert reloaded_run.metadata["cancelled_at"]

      assert Repo.get!(InventoryBatch, running_batch.id).status == :cancelled
      assert Repo.get!(InventoryBatch, failed_batch.id).status == :failed
    end
  end
end
