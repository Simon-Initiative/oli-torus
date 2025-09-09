defmodule OliWeb.Admin.UploadPipelineViewTest do
  use OliWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Oli.Factory

  alias OliWeb.Admin.UploadPipelineView

  @moduledoc false

  # - Verifies access control to the XAPI upload pipeline view
  # - Renders stats blocks and pending uploads with re-enqueue button visibility
  # - Updates pending count and stats on handle_info messages

  @route Routes.live_path(OliWeb.Endpoint, UploadPipelineView)

  describe "access control" do
    test "redirects to new session when accessing upload pipeline while not logged in", %{
      conn: conn
    } do
      assert {:error, {:redirect, %{to: "/authors/log_in"}}} = live(conn, @route)
    end

    test "redirects to authoring workspace when accessing upload pipeline as non-admin author", %{
      conn: conn
    } do
      author = insert(:author)
      conn = log_in_author(conn, author)
      assert {:error, {:redirect, %{to: "/workspaces/course_author"}}} = live(conn, @route)
    end
  end

  describe "system admin view" do
    setup [:admin_conn]

    test "renders stats and pending uploads blocks", %{conn: conn} do
      {:ok, _view, html} = live(conn, @route)

      assert html =~ "Batch Size"
      assert html =~ "S3 Upload Time"
      assert html =~ "Throughput"
      assert html =~ "Pending Uploads"
    end

    test "shows re-enqueue button only when pending_count is greater than zero", %{conn: conn} do
      # Ensure empty table and verify button hidden
      Oli.Repo.delete_all(Oli.Analytics.XAPI.PendingUpload)

      {:ok, view, _} = live(conn, @route)
      refute render(view) =~ "Re-enqueue"

      # Insert a pending upload and refresh count via info message
      Oli.Repo.insert!(%Oli.Analytics.XAPI.PendingUpload{reason: :failed, bundle: %{}})
      send(view.pid, :query_pending_uploads)

      assert render(view) =~ "Re-enqueue"
    end

    test "updates stats when receiving a :stats message", %{conn: conn} do
      {:ok, view, _} = live(conn, @route)

      send(view.pid, {:stats, {10, 250}})
      html = render(view)
      assert html =~ "10"
      assert html =~ "250"
      assert html =~ "0.0 statements/s"
    end

    test "updates pending count when receiving :query_pending_uploads message", %{conn: conn} do
      Oli.Repo.delete_all(Oli.Analytics.XAPI.PendingUpload)
      {:ok, view, _} = live(conn, @route)
      assert render(view) =~ "0 total bundles"

      Oli.Repo.insert!(%Oli.Analytics.XAPI.PendingUpload{reason: :failed, bundle: %{}})
      send(view.pid, :query_pending_uploads)
      assert render(view) =~ "1 total bundles"
    end
  end
end
