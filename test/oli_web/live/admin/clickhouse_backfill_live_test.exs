defmodule OliWeb.Admin.ClickhouseBackfillLiveTest do
  use OliWeb.ConnCase, async: true
  use Oban.Testing, repo: Oli.Repo

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Repo
  alias Oli.Analytics.Backfill.{BackfillRun, Inventory, InventoryBatch, InventoryRun}
  alias OliWeb.Admin.ClickhouseBackfillLive

  @route Routes.live_path(OliWeb.Endpoint, ClickhouseBackfillLive)

  describe "access control" do
    test "redirects unauthenticated visitor to author login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/authors/log_in"}}} = live(conn, @route)
    end

    test "redirects non-admin author to workspace", %{conn: conn} do
      author = insert(:author)
      conn = log_in_author(conn, author)
      assert {:error, {:redirect, %{to: "/workspaces/course_author"}}} = live(conn, @route)
    end
  end

  describe "system admin" do
    setup [:admin_conn]

    test "shows batch orchestration tab by default", %{conn: conn} do
      {:ok, _view, html} = live(conn, @route)

      assert html =~ "ClickHouse Bulk Backfill"
      assert html =~ "Schedule Batch Orchestration"
      assert html =~ "Inventory Runs"
    end

    test "can switch to manual backfill tab", %{conn: conn} do
      {:ok, view, html} = live(conn, @route)

      assert html =~ "Batch Orchestration"

      view
      |> element("button[phx-value-tab=\"manual\"]")
      |> render_click()

      assert_patch(view, ~p"/admin/clickhouse/backfill?active_tab=manual")

      rendered = render(view)
      assert rendered =~ "Schedule Backfill"
      assert rendered =~ "Recent Runs"
    end

    test "respects active_tab param", %{conn: conn} do
      {:ok, _view, html} = live(conn, @route <> "?active_tab=manual")

      assert html =~ "Schedule Backfill"
      assert html =~ "Recent Runs"
    end

    test "treats batch param as inventory tab", %{conn: conn} do
      {:ok, _view, html} = live(conn, @route <> "?active_tab=batch")

      assert html =~ "Schedule Batch Orchestration"
      assert html =~ "Inventory Runs"
    end

    test "inventory form defaults to previous day", %{conn: conn} do
      {:ok, _view, html} = live(conn, @route)

      yesterday =
        Date.utc_today()
        |> Date.add(-1)
        |> Date.to_iso8601()

      assert html =~ "value=\"#{yesterday}\""
    end

    test "shows batch progress", %{conn: conn} do
      run =
        %InventoryRun{
          inventory_date: ~D[2024-07-01],
          inventory_prefix: "prefix",
          manifest_url: "https://example.com/manifest.json",
          manifest_bucket: "bucket",
          target_table: "analytics.raw_events",
          format: "JSONAsString",
          status: :running,
          total_batches: 1
        }
        |> Repo.insert!()

      %InventoryBatch{
        run_id: run.id,
        sequence: 1,
        parquet_key: "key",
        processed_objects: 5,
        object_count: 10,
        status: :running
      }
      |> Repo.insert!()

      {:ok, _view, html} = live(conn, @route)

      assert html =~ "50.0% complete"
    end

    test "schedules inventory dry run", %{conn: conn} do
      Repo.delete_all(InventoryRun)
      Oban.Testing.reset()

      {:ok, view, _html} = live(conn, @route)

      params = %{
        "inventory_date" => "2024-07-01",
        "target_table" => "analytics.raw_events",
        "dry_run" => "true"
      }

      view
      |> form("form[phx-submit=\"inventory_schedule\"]", %{"inventory" => params})
      |> render_submit()

      assert [%InventoryRun{} = run] = Repo.all(InventoryRun)
      assert run.dry_run
      assert run.metadata["dry_run"]
      assert run.metadata["max_simultaneous_batches"] == 1
      assert run.metadata["max_batch_retries"] == 1

      rendered = render(view)
      assert rendered =~ "Dry run: Yes"
      assert rendered =~ "Inventory batch run has been enqueued"
    end

    test "inventory scheduling uses config-driven defaults", %{conn: conn} do
      Repo.delete_all(InventoryRun)
      Oban.Testing.reset()

      {:ok, view, _html} = live(conn, @route)

      params = %{
        "inventory_date" => "2024-07-02",
        "target_table" => "analytics.custom_events"
      }

      view
      |> form("form[phx-submit=\"inventory_schedule\"]", %{"inventory" => params})
      |> render_submit()

      assert [%InventoryRun{} = run] = Repo.all(InventoryRun)
      assert run.metadata["max_simultaneous_batches"] == 1
      assert run.metadata["max_batch_retries"] == 1
      refute run.dry_run

      rendered = render(view)
      assert rendered =~ "Inventory batch run has been enqueued"
    end

    test "allows deleting completed backfill run", %{conn: conn} do
      Repo.delete_all(BackfillRun)

      run =
        %BackfillRun{
          target_table: "analytics.raw_events",
          s3_pattern: "s3://bucket/path/**/*.jsonl",
          format: "JSONAsString",
          status: :completed
        }
        |> Repo.insert!()

      {:ok, view, _html} = live(conn, @route)

      view
      |> element("button[phx-click=\"delete_backfill_run\"][phx-value-id=\"#{run.id}\"]")
      |> render_click()

      refute Repo.get(BackfillRun, run.id)
      assert render(view) =~ "Run #{run.id} deleted"
    end

    test "allows deleting completed inventory run", %{conn: conn} do
      Repo.delete_all(InventoryRun)

      run =
        %InventoryRun{
          inventory_date: ~D[2024-08-01],
          inventory_prefix: "inventory/prefix",
          manifest_url: "https://example.com/manifest.json",
          manifest_bucket: "test-inventory-bucket",
          target_table: "analytics.raw_events",
          format: "JSONAsString",
          status: :completed
        }
        |> Repo.insert!()

      {:ok, view, _html} = live(conn, @route)

      view
      |> element("button[phx-click=\"delete_inventory_run\"][phx-value-id=\"#{run.id}\"]")
      |> render_click()

      refute Repo.get(InventoryRun, run.id)
      assert render(view) =~ "Inventory run #{run.id} deleted"
    end

    test "shows validation error for invalid JSON settings", %{conn: conn} do
      {:ok, view, _html} = live(conn, @route)

      params = %{
        "s3_pattern" => "s3://bucket/**/*.jsonl",
        "target_table" => "analytics.raw_events",
        "format" => "JSONAsString",
        "clickhouse_settings" => "{not-json}"
      }

      html = render_change(view, "validate", %{"backfill" => params})

      assert html =~ "invalid JSON"
      refute html =~ "Backfill job has been enqueued"
    end

    test "enqueues backfill job on submit", %{conn: conn} do
      Repo.delete_all(BackfillRun)

      {:ok, view, _html} = live(conn, @route)

      params = %{
        "s3_pattern" => "s3://bucket/**/*.jsonl",
        "target_table" => "analytics.raw_events",
        "format" => "JSONAsString",
        "dry_run" => "true"
      }

      html =
        view
        |> form("form[phx-submit=\"schedule\"]", %{"backfill" => params})
        |> render_submit()

      assert html =~ "Backfill job has been enqueued"

      assert [%BackfillRun{} = run] = Repo.all(BackfillRun)
      assert run.s3_pattern == "s3://bucket/**/*.jsonl"
      assert run.dry_run

      assert_enqueued(worker: Oli.Analytics.Backfill.Worker, args: %{"run_id" => run.id})
    end

    test "normalizes https S3 URLs to s3:// notation", %{conn: conn} do
      Repo.delete_all(BackfillRun)

      {:ok, view, _html} = live(conn, @route)

      params = %{
        "s3_pattern" => "https://torus-xapi-dev.s3.amazonaws.com/section/test/**/*.jsonl",
        "target_table" => "analytics.raw_events",
        "format" => "JSONAsString"
      }

      view
      |> form("form[phx-submit=\"schedule\"]", %{"backfill" => params})
      |> render_submit()

      assert [%BackfillRun{} = run] = Repo.all(BackfillRun)
      assert run.s3_pattern == "s3://torus-xapi-dev/section/test/**/*.jsonl"
    end

    test "normalizes s3 URL containing regional host", %{conn: conn} do
      Repo.delete_all(BackfillRun)

      {:ok, view, _html} = live(conn, @route)

      params = %{
        "s3_pattern" => "s3://torus-xapi-dev.s3.amazonaws.com/section/test/**/*.jsonl",
        "target_table" => "analytics.raw_events",
        "format" => "JSONAsString"
      }

      view
      |> form("form[phx-submit=\"schedule\"]", %{"backfill" => params})
      |> render_submit()

      assert [%BackfillRun{} = run] = Repo.all(BackfillRun)
      assert run.s3_pattern == "s3://torus-xapi-dev/section/test/**/*.jsonl"
    end

    test "renders progress bar for running run", %{conn: conn} do
      Repo.delete_all(BackfillRun)

      Repo.insert!(%BackfillRun{
        target_table: "analytics.raw_events",
        s3_pattern: "s3://bucket/path/**/*.jsonl",
        format: "JSONAsString",
        status: :running,
        dry_run: true,
        query_id: "progress-query",
        metadata: %{
          "progress" => %{
            "percent" => 42.5,
            "read_rows" => 425,
            "total_rows" => 1_000
          }
        }
      })

      {:ok, _view, html} = live(conn, @route)

      assert html =~ "width: 42.5%"
      assert html =~ "Rows: 425 / 1000 (42.5%)"
    end

    test "retry inventory batch enqueues job", %{conn: conn} do
      Oban.Testing.reset()

      run =
        %InventoryRun{
          inventory_date: ~D[2024-07-01],
          inventory_prefix: "torus/inventory/2024-07-01",
          manifest_url: "https://example.com/manifest.json",
          manifest_bucket: "test-inventory-bucket",
          target_table: "analytics.raw_events",
          format: "JSONAsString",
          status: :failed,
          dry_run: false,
          total_batches: 1,
          failed_batches: 1,
          completed_batches: 0,
          running_batches: 0,
          pending_batches: 0
        }
        |> Repo.insert!()

      batch =
        %InventoryBatch{
          run_id: run.id,
          sequence: 1,
          parquet_key: "torus/path/file.parquet",
          status: :failed,
          object_count: 10,
          processed_objects: 4,
          attempts: 1,
          metadata: %{}
        }
        |> Repo.insert!()

      {:ok, view, _html} = live(conn, @route)

      view
      |> element("button[phx-value-tab=\"inventory\"]")
      |> render_click()

      view
      |> element("button[phx-click=\"retry_inventory_batch\"][phx-value-id=\"#{batch.id}\"]")
      |> render_click()

      assert_enqueued(
        worker: Oli.Analytics.Backfill.Inventory.BatchWorker,
        args: %{"batch_id" => batch.id}
      )

      assert [%{max_attempts: 1}] =
               all_enqueued(worker: Oli.Analytics.Backfill.Inventory.BatchWorker)

      assert render(view) =~ "retry queued"
    end

    test "cancel inventory run transitions status to cancelled", %{conn: conn} do
      run =
        %InventoryRun{
          inventory_date: ~D[2024-07-01],
          inventory_prefix: "torus/inventory/2024-07-01",
          manifest_url: "https://example.com/manifest.json",
          manifest_bucket: "test-inventory-bucket",
          target_table: "analytics.raw_events",
          format: "JSONAsString",
          status: :running,
          dry_run: false,
          total_batches: 2,
          running_batches: 1,
          pending_batches: 1
        }
        |> Repo.insert!()

      running_batch =
        %InventoryBatch{
          run_id: run.id,
          sequence: 1,
          parquet_key: "torus/path/running.parquet",
          status: :running,
          object_count: 10,
          processed_objects: 4
        }
        |> Repo.insert!()

      failed_batch =
        %InventoryBatch{
          run_id: run.id,
          sequence: 2,
          parquet_key: "torus/path/failed.parquet",
          status: :failed,
          object_count: 8,
          processed_objects: 8
        }
        |> Repo.insert!()

      _ = Inventory.recompute_run_aggregates(run)

      {:ok, view, _html} = live(conn, @route)

      view
      |> element("button[phx-value-tab=\"inventory\"]")
      |> render_click()

      view
      |> element("button[phx-click=\"cancel_inventory_run\"][phx-value-id=\"#{run.id}\"]")
      |> render_click()

      run = Repo.get!(InventoryRun, run.id)
      running_batch = Repo.get!(InventoryBatch, running_batch.id)
      failed_batch = Repo.get!(InventoryBatch, failed_batch.id)

      assert run.status == :cancelled
      refute is_nil(run.finished_at)
      assert running_batch.status == :cancelled
      assert failed_batch.status == :failed

      rendered = render(view)
      assert rendered =~ "Run #{run.id} cancellation requested"
      assert rendered =~ "Cancelled"
    end

    test "cancel inventory batch transitions status to cancelled", %{conn: conn} do
      run =
        %InventoryRun{
          inventory_date: ~D[2024-07-01],
          inventory_prefix: "torus/inventory/2024-07-01",
          manifest_url: "https://example.com/manifest.json",
          manifest_bucket: "test-inventory-bucket",
          target_table: "analytics.raw_events",
          format: "JSONAsString",
          status: :running,
          dry_run: false,
          total_batches: 1,
          running_batches: 1
        }
        |> Repo.insert!()

      batch =
        %InventoryBatch{
          run_id: run.id,
          sequence: 1,
          parquet_key: "torus/path/running.parquet",
          status: :running,
          object_count: 12,
          processed_objects: 6
        }
        |> Repo.insert!()

      _ = Inventory.recompute_run_aggregates(run)

      {:ok, view, _html} = live(conn, @route)

      view
      |> element("button[phx-value-tab=\"inventory\"]")
      |> render_click()

      view
      |> element("button[phx-click=\"cancel_inventory_batch\"][phx-value-id=\"#{batch.id}\"]")
      |> render_click()

      batch = Repo.get!(InventoryBatch, batch.id)
      run = Repo.get!(InventoryRun, run.id)

      assert batch.status == :cancelled
      assert run.running_batches in [0, nil]

      rendered = render(view)
      assert rendered =~ "Batch #{batch.id} cancellation requested"
    end
  end
end
