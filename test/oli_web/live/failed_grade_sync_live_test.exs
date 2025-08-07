defmodule OliWeb.FailedGradeSyncLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import ExUnit.CaptureLog
  import Oli.Factory
  import Phoenix.LiveViewTest

  defp live_view_overview_view_route(section_slug) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Sections.OverviewView,
      section_slug
    )
  end

  defp live_view_observe_grade_updates_view_route(section_slug) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Grades.ObserveGradeUpdatesView,
      section_slug
    )
  end

  defp live_view_failed_grade_sync_view_route(section_slug) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Grades.FailedGradeSyncLive,
      section_slug
    )
  end

  describe "user cannot access when is not logged in" do
    setup [:section_with_assessment]

    test "redirects to enroll page when accessing the failed grade sync view", %{
      conn: conn,
      section: section
    } do
      redirect_path = "/users/log_in"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_failed_grade_sync_view_route(section.slug))
    end
  end

  describe "user cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn, :section_with_assessment]

    test "redirects to section enroll page when accessing the failed grade sync view", %{
      conn: conn,
      section: section
    } do
      redirect_path = "/users/log_in"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_failed_grade_sync_view_route(section.slug))
    end
  end

  describe "user can access when is logged in as an instructor" do
    setup [:lms_instructor_conn, :section_with_assessment, :create_failed_resource_accesses]

    test "loads correctly", %{
      conn: conn,
      instructor: instructor,
      section: section,
      resource_access_1: resource_access_1,
      resource_access_2: resource_access_2
    } do
      enroll_user_to_section(instructor, section, :context_instructor)

      {:ok, view, _html} = live(conn, live_view_failed_grade_sync_view_route(section.slug))

      assert has_element?(view, "#failed-sync-grades-table")
      assert has_element?(view, "button[phx-click='bulk-retry']", "Retry all")
      assert has_element?(view, "##{resource_access_1.id}")
      assert has_element?(view, "##{resource_access_2.id}")
    end

    test "redirects correctly when retrying", %{
      conn: conn,
      instructor: instructor,
      section: section,
      resource_access_1: %{resource_id: resource_id, user_id: user_id}
    } do
      enroll_user_to_section(instructor, section, :context_instructor)

      {:ok, view, _html} = live(conn, live_view_failed_grade_sync_view_route(section.slug))

      view
      |> element("button[phx-click='retry'][phx-value-user-id='#{user_id}'")
      |> render_click(%{"resource-id" => resource_id, "user-id" => user_id})

      flash = assert_redirected(view, live_view_overview_view_route(section.slug))

      assert flash["info"] ==
               "Retrying grade sync. Please check the status again in a few minutes."
    end
  end

  describe "failed grade sync view" do
    setup [:admin_conn, :section_with_assessment, :create_failed_resource_accesses]

    test "loads correctly", %{
      conn: conn,
      section: section,
      resource_access_1: resource_access_1,
      resource_access_2: resource_access_2
    } do
      {:ok, view, _html} = live(conn, live_view_failed_grade_sync_view_route(section.slug))

      assert has_element?(view, "#failed-sync-grades-table")
      assert has_element?(view, "button[phx-click='bulk-retry']", "Retry all")
      assert has_element?(view, "##{resource_access_1.id}")
      assert has_element?(view, "##{resource_access_2.id}")
    end

    test "applies sorting", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, live_view_failed_grade_sync_view_route(section.slug))

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               "AAAA Name"

      view
      |> element("th[phx-click='sort']:first-of-type")
      |> render_click(%{sort_by: "user_name"})

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               "BBBB Name"
    end

    test "applies searching", %{
      conn: conn,
      section: section,
      resource_access_1: resource_access_1,
      resource_access_2: resource_access_2
    } do
      {:ok, view, _html} = live(conn, live_view_failed_grade_sync_view_route(section.slug))

      view
      |> element("input[phx-blur=\"change_search\"]")
      |> render_blur(%{value: "aaaa"})

      view
      |> element("button[phx-click='apply_search']")
      |> render_click()

      assert has_element?(view, "##{resource_access_1.id}")
      refute has_element?(view, "##{resource_access_2.id}")

      view
      |> element("button[phx-click='reset_search']")
      |> render_click()

      assert has_element?(view, "##{resource_access_1.id}")
      assert has_element?(view, "##{resource_access_2.id}")
    end

    test "applies paging", %{
      conn: conn,
      section: section,
      page_revision: page_revision,
      last_successful_grade_update: last_successful_grade_update,
      last_grade_update: last_grade_update
    } do
      insert_list(
        19,
        :resource_access,
        section: section,
        resource: page_revision.resource,
        last_successful_grade_update_id: last_successful_grade_update.id,
        last_grade_update_id: last_grade_update.id
      )

      {:ok, view, _html} = live(conn, live_view_failed_grade_sync_view_route(section.slug))

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               "AAAA Name"

      view
      |> element("button[phx-click='page_change']", "2")
      |> render_click()

      refute view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               "AAAA Name"
    end

    test "renders error message correctly", %{
      conn: conn,
      section: section,
      resource_access_1: %{user_id: user_id}
    } do
      assert capture_log(fn ->
               {:ok, view, _html} =
                 live(conn, live_view_failed_grade_sync_view_route(section.slug))

               view
               |> element("button[phx-click='retry'][phx-value-user-id='#{user_id}'")
               |> render_click(%{"resource-id" => -1, "user-id" => user_id})

               assert view
                      |> element("div#flash")
                      |> render() =~
                        "Couldn&#39;t retry grade sync."
             end) =~
               "Couldn't retry grade sync for resource_id: -1, user_id: #{user_id}. Reason: {:error, {\"The resource access was not found.\"}}"
    end

    test "retries individual failed grade sync correctly", %{
      conn: conn,
      section: section,
      resource_access_1: %{id: id, resource_id: resource_id, user_id: user_id}
    } do
      {:ok, view, _html} = live(conn, live_view_failed_grade_sync_view_route(section.slug))

      view
      |> element("button[phx-click='retry'][phx-value-user-id='#{user_id}'")
      |> render_click(%{"resource-id" => resource_id, "user-id" => user_id})

      flash = assert_redirected(view, live_view_observe_grade_updates_view_route(section.slug))
      assert flash["info"] == "Retrying grade sync. See processing in real time below."

      [%Oban.Job{args: args, queue: "grades"}] =
        Oli.Delivery.Attempts.PageLifecycle.GradeUpdateWorker.get_jobs()

      assert %{
               "resource_access_id" => id,
               "section_id" => section.id,
               "type" => "manual"
             } == args
    end

    test "retries bulk failed grade sync correctly", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, live_view_failed_grade_sync_view_route(section.slug))

      view
      |> element("button[phx-click='bulk-retry']")
      |> render_click()

      flash = assert_redirected(view, live_view_observe_grade_updates_view_route(section.slug))
      assert flash["info"] == "Retrying grade sync. See processing in real time below."

      assert [
               %Oban.Job{args: %{"type" => "manual_batch"}, queue: "grades"},
               %Oban.Job{args: %{"type" => "manual_batch"}, queue: "grades"}
             ] = Oli.Delivery.Attempts.PageLifecycle.GradeUpdateWorker.get_jobs()
    end
  end

  defp create_failed_resource_accesses(%{
         conn: conn,
         section: section,
         page_revision: page_revision
       }) do
    first_user = insert(:user, name: "AAAA Name")
    second_user = insert(:user, name: "BBBB Name")

    last_successful_grade_update = insert(:lms_grade_update)
    last_grade_update = insert(:lms_grade_update)

    resource_access_1 =
      insert(:resource_access,
        user: first_user,
        section: section,
        resource: page_revision.resource,
        last_successful_grade_update_id: last_successful_grade_update.id,
        last_grade_update_id: last_grade_update.id
      )

    resource_access_2 =
      insert(:resource_access,
        user: second_user,
        section: section,
        resource: page_revision.resource,
        last_successful_grade_update_id: last_successful_grade_update.id,
        last_grade_update_id: last_grade_update.id
      )

    {:ok,
     conn: conn,
     section: section,
     page_revision: page_revision,
     last_successful_grade_update: last_successful_grade_update,
     last_grade_update: last_grade_update,
     resource_access_1: resource_access_1,
     resource_access_2: resource_access_2}
  end
end
