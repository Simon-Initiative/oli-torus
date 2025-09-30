defmodule OliWeb.Admin.ClickhouseBackfillLiveTest do
  use OliWeb.ConnCase, async: true
  use Oban.Testing, repo: Oli.Repo

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Repo
  alias Oli.Analytics.Backfill.BackfillRun
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

    test "renders backfill form and recent runs table", %{conn: conn} do
      {:ok, _view, html} = live(conn, @route)

      assert html =~ "ClickHouse Bulk Backfill"
      assert html =~ "Schedule Backfill"
      assert html =~ "Recent Runs"
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

      html = render_submit(view, %{"backfill" => params})

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

      render_submit(view, %{"backfill" => params})

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

      render_submit(view, %{"backfill" => params})

      assert [%BackfillRun{} = run] = Repo.all(BackfillRun)
      assert run.s3_pattern == "s3://torus-xapi-dev/section/test/**/*.jsonl"
    end
  end
end
