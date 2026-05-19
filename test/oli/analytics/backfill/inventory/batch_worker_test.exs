defmodule Oli.Analytics.Backfill.Inventory.BatchWorkerTest do
  use Oli.DataCase, async: false
  use Oban.Testing, repo: Oli.Repo

  alias Oli.Analytics.Backfill.Inventory.BatchWorker
  alias Oli.Analytics.Backfill.InventoryBatch
  alias Oli.Analytics.Backfill.InventoryRun
  alias Oli.Repo

  defmodule ControlledAnalytics do
    alias Oli.Analytics.Backfill.InventoryBatch
    alias Oli.Repo

    def execute_query(_query, description, _opts) do
      cond do
        String.starts_with?(description, "inventory manifest count ") ->
          rows = Process.get(:inventory_manifest_rows, [])

          {:ok,
           %{parsed_body: %{"data" => [%{"object_count" => Integer.to_string(length(rows))}]}}}

        String.starts_with?(description, "inventory manifest batch ") ->
          rows = Process.get(:inventory_manifest_rows, [])
          offset = extract_offset(description)

          {:ok, %{parsed_body: %{"data" => Enum.drop(rows, offset)}}}

        String.starts_with?(description, "inventory batch ") ->
          batch_id = extract_batch_id(description)

          case Process.get(:failing_batch_id) do
            ^batch_id -> {:error, "chunk insert failed"}
            _ -> {:ok, %{body: "", execution_time_ms: 5.0}}
          end

        true ->
          {:ok, %{parsed_body: %{"data" => []}}}
      end
    end

    def query_status(query_id, _opts) do
      maybe_apply_interruption(query_id)

      {:ok,
       %{
         status: :completed,
         rows_read: 1,
         rows_written: 1,
         bytes_read: 128,
         bytes_written: 64,
         query_duration_ms: 5
       }}
    end

    defp maybe_apply_interruption(query_id) do
      interrupt_action = Process.get(:interrupt_action)

      if interrupt_action && !Process.get(:interrupt_applied, false) do
        batch_id = extract_query_batch_id(query_id)
        batch = Repo.get!(InventoryBatch, batch_id)

        metadata =
          case interrupt_action do
            :pause ->
              %{"chunk_count" => 0, "chunk_sequence" => 0, "paused_at" => DateTime.utc_now()}

            :cancel ->
              %{"chunk_count" => 0, "chunk_sequence" => 0, "cancelled_at" => DateTime.utc_now()}
          end

        batch
        |> InventoryBatch.changeset(%{
          status: if(interrupt_action == :pause, do: :paused, else: :cancelled),
          metadata: Map.merge(batch.metadata || %{}, metadata)
        })
        |> Repo.update!()

        Process.put(:interrupt_applied, true)
      end
    end

    defp extract_offset(description) do
      case Regex.run(~r/offset (\d+)/, description, capture: :all_but_first) do
        [offset] -> String.to_integer(offset)
        _ -> 0
      end
    end

    defp extract_batch_id(description) do
      case Regex.run(~r/inventory batch (\d+) chunk/, description, capture: :all_but_first) do
        [batch_id] -> String.to_integer(batch_id)
        _ -> nil
      end
    end

    defp extract_query_batch_id(query_id) do
      case Regex.run(~r/torus_inventory_batch_(\d+)_/, query_id, capture: :all_but_first) do
        [batch_id] -> String.to_integer(batch_id)
        _ -> raise "unable to extract batch id from query id: #{inspect(query_id)}"
      end
    end
  end

  setup do
    original_analytics = Application.get_env(:oli, :clickhouse_analytics_module)
    original_inventory = Application.get_env(:oli, :clickhouse_inventory)

    Application.put_env(:oli, :clickhouse_analytics_module, ControlledAnalytics)

    Application.put_env(:oli, :clickhouse_inventory, %{
      manifest_access_key_id: "test-key",
      manifest_secret_access_key: "test-secret",
      batch_chunk_size: 1,
      manifest_page_size: 100,
      max_simultaneous_batches: 1,
      max_batch_retries: 1
    })

    Process.put(:inventory_manifest_rows, [])
    Process.delete(:failing_batch_id)
    Process.delete(:interrupt_action)
    Process.delete(:interrupt_applied)

    on_exit(fn ->
      if original_analytics do
        Application.put_env(:oli, :clickhouse_analytics_module, original_analytics)
      else
        Application.delete_env(:oli, :clickhouse_analytics_module)
      end

      if original_inventory do
        Application.put_env(:oli, :clickhouse_inventory, original_inventory)
      else
        Application.delete_env(:oli, :clickhouse_inventory)
      end

      Process.delete(:inventory_manifest_rows)
      Process.delete(:failing_batch_id)
      Process.delete(:interrupt_action)
      Process.delete(:interrupt_applied)
    end)

    :ok
  end

  describe "perform/1 interruption handling" do
    test "honors pause intent after a completed chunk" do
      run = insert_run(%{dry_run: false})
      batch = insert_batch(run, %{status: :pending})

      Process.put(
        :inventory_manifest_rows,
        [
          %{"bucket" => "bucket-a", "key" => "events/a-1.jsonl"},
          %{"bucket" => "bucket-b", "key" => "events/b-1.jsonl"}
        ]
      )

      Process.put(:interrupt_action, :pause)

      assert {:ok, _batch} = BatchWorker.perform(%Oban.Job{args: %{"batch_id" => batch.id}})

      updated_batch = Repo.get!(InventoryBatch, batch.id)
      assert updated_batch.status == :paused
      assert updated_batch.processed_objects == 1
      assert updated_batch.metadata["paused_at"]
    end

    test "honors cancel intent after a completed chunk" do
      run = insert_run(%{dry_run: false})
      batch = insert_batch(run, %{status: :pending})

      Process.put(
        :inventory_manifest_rows,
        [
          %{"bucket" => "bucket-a", "key" => "events/a-1.jsonl"},
          %{"bucket" => "bucket-b", "key" => "events/b-1.jsonl"}
        ]
      )

      Process.put(:interrupt_action, :cancel)

      assert {:ok, _batch} = BatchWorker.perform(%Oban.Job{args: %{"batch_id" => batch.id}})

      updated_batch = Repo.get!(InventoryBatch, batch.id)
      assert updated_batch.status == :cancelled
      assert updated_batch.processed_objects == 1
      assert updated_batch.metadata["cancelled_at"]
    end
  end

  describe "perform/1 failure isolation" do
    test "leaves the run active and enqueues remaining work when one batch fails" do
      run = insert_run(%{dry_run: false, status: :running})
      failing_batch = insert_batch(run, %{status: :pending, sequence: 1})

      queued_batch =
        insert_batch(run, %{status: :pending, sequence: 2, parquet_key: "inventory/2.parquet"})

      Process.put(
        :inventory_manifest_rows,
        [
          %{"bucket" => "bucket-a", "key" => "events/a-1.jsonl"}
        ]
      )

      Process.put(:failing_batch_id, failing_batch.id)

      assert {:error, message} =
               BatchWorker.perform(%Oban.Job{args: %{"batch_id" => failing_batch.id}})

      assert message =~ "chunk insert failed"

      updated_run = Repo.get!(InventoryRun, run.id)
      assert updated_run.status == :running
      assert updated_run.failed_batches == 1
      assert updated_run.pending_batches == 1

      assert Repo.get!(InventoryBatch, failing_batch.id).status == :failed
      assert Repo.get!(InventoryBatch, queued_batch.id).status == :queued

      assert [%Oban.Job{args: %{"batch_id" => queued_batch_id}}] =
               all_enqueued(worker: BatchWorker)

      assert queued_batch_id == queued_batch.id
    end
  end

  defp insert_run(attrs) do
    defaults = %{
      inventory_date: ~D[2024-07-12],
      inventory_prefix: "inventory/prefix/2024-07-12",
      manifest_url: "https://example.com/manifest.json",
      manifest_bucket: "test-bucket",
      target_table: "analytics.raw_events",
      format: "JSONAsString",
      status: :running,
      dry_run: true,
      metadata: %{
        "batch_chunk_size" => 1,
        "manifest_page_size" => 100,
        "max_simultaneous_batches" => 1,
        "max_batch_retries" => 1
      }
    }

    %InventoryRun{}
    |> InventoryRun.creation_changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp insert_batch(run, attrs) do
    defaults = %{
      run_id: run.id,
      sequence: 1,
      parquet_key: "inventory/1.parquet",
      status: :pending,
      metadata: %{}
    }

    %InventoryBatch{}
    |> InventoryBatch.creation_changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end
end
