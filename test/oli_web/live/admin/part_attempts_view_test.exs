defmodule OliWeb.Admin.PartAttemptsViewTest do
  use OliWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Oli.Factory

  @moduledoc false

  # - Verifies access control for unauthenticated and non-admin users
  # - Renders initial stopped state with zero counters and controls
  # - Updates UI when receiving progress messages and when changing wait time

  @live_view_route Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.PartAttemptsView)

  describe "access control" do
    test "redirects to new session when accessing the part attempts view while not logged in", %{
      conn: conn
    } do
      assert {:error, {:redirect, %{to: "/authors/log_in"}}} = live(conn, @live_view_route)
    end

    test "redirects to authoring workspace when accessing the part attempts view as a non-admin author",
         %{conn: conn} do
      author = insert(:author)
      conn = log_in_author(conn, author)

      assert {:error, {:redirect, %{to: "/workspaces/course_author"}}} =
               live(conn, @live_view_route)
    end
  end

  describe "system admin interactions" do
    setup [:admin_conn]

    test "renders stopped status with zero counters and shows controls", %{conn: conn} do
      {:ok, _view, html} = live(conn, @live_view_route)

      assert html =~ "Stopped"
      assert html =~ "Batches: 0"
      assert html =~ "Records Visited: 0"
      assert html =~ "Records Deleted: 0"
      # Buttons exist with the expected events
      assert html =~ ~s(phx-click="stop")
      assert html =~ ~s(phx-click="start")
    end

    test "updates stats and messages when a batch finishes", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_route)

      state = %{
        running: true,
        batches_complete: 5,
        records_visited: 100,
        records_deleted: 25,
        wait_time: 0
      }

      details = %{id: 123, records_deleted: 2, records_visited: 10}

      send(view.pid, {:batch_finished, state, details})

      rendered = render(view)

      assert rendered =~ "Running"
      assert rendered =~ "Batches: 5"
      assert rendered =~ "Records Visited: 100"
      assert rendered =~ "Records Deleted: 25"
      assert rendered =~ "] 2 deleted out of 10 visited"
    end

    test "shows no-more-attempts message and reflects stopped status", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_route)

      state = %{
        running: false,
        batches_complete: 7,
        records_visited: 300,
        records_deleted: 200,
        wait_time: 0
      }

      send(view.pid, {:no_more_attempts, state})

      rendered = render(view)
      assert rendered =~ "No more attempts to clean"
      assert rendered =~ "Stopped"
    end
  end
end
