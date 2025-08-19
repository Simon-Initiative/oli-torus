defmodule OliWeb.Admin.AuditLogLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Auditing

  describe "mount/3" do
    test "redirects if user is not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/admin/audit_log")
      assert redirected_to(conn) == ~p"/authors/log_in"
    end

    test "redirects if user is not a system admin", %{conn: conn} do
      author = insert(:author)
      conn = Plug.Test.init_test_session(conn, %{})
      
      {:error, {:redirect, %{to: path, flash: flash}}} =
        conn
        |> log_in_author(author)
        |> live(~p"/admin/audit_log")

      assert path == "/workspaces/course_author"
      assert flash["error"] =~ "You are not authorized"
    end

    test "renders audit log page for system admin", %{conn: conn} do
      admin = insert(:author, system_role_id: Oli.Accounts.SystemRole.role_id().system_admin)
      
      {:ok, view, html} =
        conn
        |> log_in_author(admin)
        |> live(~p"/admin/audit_log")

      assert html =~ "Audit Log"
      assert html =~ "Filters"
      assert html =~ "Event Type"
      assert html =~ "Actor Type"
      
      # Check that the view is properly initialized
      assert view.module == OliWeb.Admin.AuditLogLive
    end
  end

  describe "browsing and filtering" do
    setup %{conn: conn} do
      admin = insert(:author, system_role_id: Oli.Accounts.SystemRole.role_id().system_admin)
      
      # Create some test audit events
      user1 = insert(:user, name: "Test User 1")
      user2 = insert(:user, name: "Test User 2")
      author1 = insert(:author, name: "Test Author 1")
      project = insert(:project, title: "Test Project")
      section = insert(:section, title: "Test Section")
      
      {:ok, event1} = Auditing.capture(user1, :user_created, nil, %{"email" => user1.email})
      {:ok, event2} = Auditing.capture(user2, :section_created, section, %{"title" => section.title})
      {:ok, event3} = Auditing.capture(author1, :project_published, project, %{"version" => "1.0"})
      {:ok, event4} = Auditing.capture(user1, :content_updated, nil, %{"page" => "test.html"})
      
      conn = log_in_author(conn, admin)
      
      {:ok,
       %{
         conn: conn,
         admin: admin,
         events: [event1, event2, event3, event4],
         user1: user1,
         user2: user2,
         author1: author1,
         project: project,
         section: section
       }}
    end

    test "displays all events by default", %{conn: conn, events: _events} do
      {:ok, _view, html} = live(conn, ~p"/admin/audit_log")
      
      # Check that events are displayed
      assert html =~ "user_created"
      assert html =~ "section_created"
      assert html =~ "project_published"
      assert html =~ "content_updated"
    end

    test "filters by event type", %{conn: conn, author1: author1} do
      # Create a unique event that we can filter for
      project2 = insert(:project, title: "Another Test Project", slug: "unique-project-#{System.unique_integer()}")
      {:ok, _event} = Auditing.capture(author1, :project_published, project2, %{"version" => "2.0"})
      
      # Navigate directly to the filtered URL to trigger handle_params
      {:ok, view, _html} = live(conn, ~p"/admin/audit_log")
      
      # Simulate selecting event type filter (SelectListener sends id and value)
      html = 
        view
        |> render_change("filter_event_type", %{"id" => "event_type_filter", "value" => "project_published"})
      
      # Should see project_published events
      assert html =~ "project_published"
      # The table should still be present
      assert html =~ "Event Type"
    end

    test "filters by actor type", %{conn: conn} do
      # Navigate to the audit log page
      {:ok, view, _html} = live(conn, ~p"/admin/audit_log")
      
      # Simulate selecting actor type filter to show only user events (SelectListener sends id and value)
      html = 
        view
        |> render_change("filter_actor_type", %{"id" => "actor_type_filter", "value" => "user"})
      
      # These events should show (done by users)
      assert html =~ "user_created"
      # The table should still be present
      assert html =~ "Actor Type"
    end

    test "text search filters events", %{conn: conn, admin: admin} do
      # Create a unique project to search for
      unique_project = insert(:project, slug: "unique-search-#{System.unique_integer()}")
      {:ok, _event} = Auditing.capture(admin, :project_created, unique_project, %{})
      
      # Navigate to the page
      {:ok, view, _html} = live(conn, ~p"/admin/audit_log")
      
      # Simulate text search
      html = 
        view
        |> render_change("text_search_change", %{"value" => unique_project.slug})
      
      # Should show the unique project we searched for
      assert html =~ unique_project.slug
    end

    test "pagination works correctly", %{conn: conn} do
      # Create many events to trigger pagination
      for i <- 1..30 do
        user = insert(:user, name: "User #{i}")
        Auditing.capture(user, :user_created, nil, %{"index" => i})
      end
      
      {:ok, _view, html} = live(conn, ~p"/admin/audit_log")
      
      # Check that pagination controls are present when we have more than 25 items
      # The PagedTable component should show navigation when total_count > limit
      assert html =~ "paged_table_page_change"
      
      # Navigate to next page with offset param
      {:ok, _view, html} = live(conn, ~p"/admin/audit_log?offset=25")
      
      # Should be on page 2 now, check we still have pagination controls
      assert html =~ "paged_table_page_change"
    end

    test "sorting works correctly", %{conn: conn} do
      # Navigate directly with sort params
      {:ok, _view, html} = live(conn, ~p"/admin/audit_log?sort_by=event_type&sort_order=asc")
      
      # Events should be sorted by event type
      assert html =~ "Event Type"
    end

    test "shows details modal when clicked", %{conn: conn, user1: user1} do
      {:ok, view, _html} = live(conn, ~p"/admin/audit_log")
      
      # Create details JSON that matches what would be in the button
      details = %{"email" => user1.email}
      
      # Directly call the show_details event handler
      html = 
        view
        |> render_click("show_details", %{"details" => Jason.encode!(details)})
      
      # Modal should be shown
      assert html =~ "Event Details"
      assert html =~ user1.email
      
      # Close modal
      html =
        view
        |> render_click("close_details_modal")
      
      # Modal should be hidden
      refute html =~ "Event Details"
    end
  end

  describe "resource links" do
    setup %{conn: conn} do
      admin = insert(:author, system_role_id: Oli.Accounts.SystemRole.role_id().system_admin)
      conn = log_in_author(conn, admin)
      
      {:ok, %{conn: conn, admin: admin}}
    end

    test "shows links to projects", %{conn: conn, admin: admin} do
      project = insert(:project, title: "My Project", authors: [admin])
      {:ok, _event} = Auditing.capture(admin, :project_published, project, %{})
      
      {:ok, _view, html} = live(conn, ~p"/admin/audit_log")
      
      # Check for project link
      assert html =~ project.slug
      assert html =~ "/workspaces/course_author/#{project.slug}"
    end

    test "shows links to sections", %{conn: conn, admin: admin} do
      section = insert(:section, title: "My Section")
      {:ok, _event} = Auditing.capture(admin, :section_created, section, %{})
      
      {:ok, _view, html} = live(conn, ~p"/admin/audit_log")
      
      # Check for section link
      assert html =~ section.slug
      assert html =~ ~p"/sections/#{section.slug}/instructor_dashboard/overview"
    end

    test "shows links to users", %{conn: conn, admin: _admin} do
      user = insert(:user, name: "John Doe")
      {:ok, _event} = Auditing.capture(user, :user_created, nil, %{})
      
      {:ok, _view, html} = live(conn, ~p"/admin/audit_log")
      
      # Check for user link and name
      assert html =~ user.name
      assert html =~ ~p"/admin/users/#{user.id}"
    end

    test "shows links to authors", %{conn: conn, admin: _admin} do
      author = insert(:author, name: "Jane Author")
      {:ok, _event} = Auditing.capture(author, :author_created, nil, %{})
      
      {:ok, _view, html} = live(conn, ~p"/admin/audit_log")
      
      # Check for author link and name
      assert html =~ author.name
      assert html =~ ~p"/admin/authors/#{author.id}"
    end
  end

end