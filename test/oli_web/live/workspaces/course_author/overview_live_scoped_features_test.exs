defmodule OliWeb.Workspaces.CourseAuthor.OverviewLiveTest.ScopedFeatures do
  use OliWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Oli.Factory
  import Oli.TestHelpers

  alias Oli.ScopedFeatureFlags

  describe "Project Overview - Scoped Features Integration" do
    setup [:admin_conn, :create_project]

    test "shows feature flags section for admin users", %{conn: conn, project: project} do
      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author/#{project.slug}/overview")

      # Should show the Feature Flags section
      assert has_element?(view, "h4", "Feature Flags")
      assert has_element?(view, "div.scoped-feature-flags-component")
    end

    test "does not show feature flags section for non-admin users", %{project: project} do
      # Create non-admin author
      author = insert(:author)
      insert(:author_project, project_id: project.id, author_id: author.id)
      conn = log_in_author(build_conn(), author)

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author/#{project.slug}/overview")

      # Should not show the Feature Flags section
      refute has_element?(view, "h4", "Feature Flags")
      refute has_element?(view, "div.scoped-feature-flags-component")
    end

    test "displays project-appropriate features", %{conn: conn, project: project} do
      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author/#{project.slug}/overview")

      # Should show authoring-scoped features
      assert has_element?(view, "td", "mcp_authoring")
      # Only mcp_authoring is defined for authoring context
    end

    test "allows enabling features when edits are enabled", %{conn: conn, project: project} do
      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author/#{project.slug}/overview")

      # Click the enable edits checkbox
      view
      |> element("input[phx-click='toggle_edits']")
      |> render_click()

      # Should show enable button for mcp_authoring
      assert has_element?(view, "button", "Enable")

      # Click enable button for mcp_authoring
      button =
        element(view, "button[phx-value-feature='mcp_authoring'][phx-value-enabled='true']")

      render_click(button)

      # Should show success message
      assert has_element?(view, "div.alert-info")

      # Feature should be enabled in database
      assert ScopedFeatureFlags.enabled?(:mcp_authoring, project)
    end

    test "handles feature toggle success messages", %{conn: conn, project: project, admin: admin} do
      # Enable a feature first
      {:ok, _} = ScopedFeatureFlags.enable_feature(:mcp_authoring, project, admin)

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author/#{project.slug}/overview")

      # Enable edits
      view
      |> element("input[phx-click='toggle_edits']")
      |> render_click()

      # Should show disable button since feature is enabled
      assert has_element?(view, "button", "Disable")

      # Disable the feature
      button =
        element(view, "button[phx-value-feature='mcp_authoring'][phx-value-enabled='false']")

      render_click(button)

      # Should show success message
      assert has_element?(view, "div.alert-info")

      # Feature should be disabled
      refute ScopedFeatureFlags.enabled?(:mcp_authoring, project)
    end

    test "component shows correct feature states", %{conn: conn, project: project, admin: admin} do
      # Enable mcp_authoring feature
      {:ok, _} = ScopedFeatureFlags.enable_feature(:mcp_authoring, project, admin)

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author/#{project.slug}/overview")

      # Should show enabled state for mcp_authoring
      assert has_element?(view, "span.bg-green-100", "Enabled")
    end
  end

  defp create_project(%{admin: admin}) do
    # Use Course.create_project to ensure proper publication and root container setup
    {:ok, %{project: project}} = Oli.Authoring.Course.create_project("Test Project", admin)
    {:ok, project: project}
  end
end
