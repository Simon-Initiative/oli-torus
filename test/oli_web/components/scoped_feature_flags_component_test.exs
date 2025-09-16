defmodule OliWeb.Components.ScopedFeatureFlagsComponentTest do
  use OliWeb.ConnCase, async: true

  import LiveComponentTests
  import Phoenix.LiveViewTest
  import Oli.Factory

  alias OliWeb.Components.ScopedFeatureFlagsComponent
  alias Oli.ScopedFeatureFlags

  describe "scoped feature flags component" do
    setup do
      author = insert(:author)
      project = insert(:project)
      section = insert(:section)

      %{author: author, project: project, section: section}
    end

    test "renders component with no features when scopes don't match", %{
      conn: conn,
      author: author,
      project: project
    } do
      attrs = %{
        id: "test_component",
        scopes: [:nonexistent_scope],
        source_id: project.id,
        source_type: :project,
        source: project,
        current_author: author
      }

      {:ok, lcd, _html} = live_component_isolated(conn, ScopedFeatureFlagsComponent, attrs)

      assert has_element?(lcd, "div.scoped-feature-flags-component")
      assert has_element?(lcd, "p", "No scoped features available")
    end

    test "renders component with matching authoring features for project", %{
      conn: conn,
      author: author,
      project: project
    } do
      attrs = %{
        id: "test_component",
        scopes: [:authoring, :both],
        source_id: project.id,
        source_type: :project,
        source: project,
        current_author: author,
        title: "Test Features"
      }

      {:ok, lcd, _html} = live_component_isolated(conn, ScopedFeatureFlagsComponent, attrs)

      assert has_element?(lcd, "div.scoped-feature-flags-component")
      assert has_element?(lcd, "h3", "Test Features")
      assert has_element?(lcd, "table")
      # Should have at least one feature (mcp_authoring)
      assert has_element?(lcd, "tbody tr")
    end

    test "renders component with matching delivery features for section", %{
      conn: conn,
      author: author,
      section: section
    } do
      attrs = %{
        id: "test_component",
        scopes: [:delivery, :both],
        source_id: section.id,
        source_type: :section,
        source: section,
        current_author: author
      }

      {:ok, lcd, _html} = live_component_isolated(conn, ScopedFeatureFlagsComponent, attrs)

      assert has_element?(lcd, "div.scoped-feature-flags-component")
      assert has_element?(lcd, "table")
      # Should have test features defined for delivery/both scopes
    end

    test "renders with edits disabled by default", %{
      conn: conn,
      author: author,
      project: project
    } do
      attrs = %{
        id: "test_component",
        scopes: [:authoring],
        source_id: project.id,
        source_type: :project,
        source: project,
        current_author: author
      }

      {:ok, lcd, _html} = live_component_isolated(conn, ScopedFeatureFlagsComponent, attrs)

      assert has_element?(lcd, "input[type='checkbox']:not([checked])")
      assert has_element?(lcd, "span", "Enable edits to modify")
    end

    test "enables editing when checkbox is clicked", %{
      conn: conn,
      author: author,
      project: project
    } do
      attrs = %{
        id: "test_component",
        scopes: [:authoring],
        source_id: project.id,
        source_type: :project,
        source: project,
        current_author: author
      }

      {:ok, lcd, _html} = live_component_isolated(conn, ScopedFeatureFlagsComponent, attrs)

      # Click the enable edits checkbox
      lcd
      |> element("input[type='checkbox']")
      |> render_click()

      assert has_element?(lcd, "input[type='checkbox'][checked]")
      assert has_element?(lcd, "button", "Enable") || has_element?(lcd, "button", "Disable")
    end

    test "displays current feature state correctly", %{
      conn: conn,
      author: author,
      project: project
    } do
      # Enable a feature first
      {:ok, _} = ScopedFeatureFlags.enable_feature(:mcp_authoring, project, author)

      attrs = %{
        id: "test_component",
        scopes: [:authoring],
        source_id: project.id,
        source_type: :project,
        source: project,
        current_author: author
      }

      {:ok, lcd, _html} = live_component_isolated(conn, ScopedFeatureFlagsComponent, attrs)

      # Should show enabled state
      assert has_element?(lcd, "span.bg-green-100", "Enabled")
    end

    test "shows disabled state for features that are not enabled", %{
      conn: conn,
      author: author,
      project: project
    } do
      attrs = %{
        id: "test_component",
        scopes: [:authoring],
        source_id: project.id,
        source_type: :project,
        source: project,
        current_author: author
      }

      {:ok, lcd, _html} = live_component_isolated(conn, ScopedFeatureFlagsComponent, attrs)

      # Should show disabled state for mcp_authoring feature
      assert has_element?(lcd, "span.bg-gray-100", "Disabled")
    end

    test "toggles feature when button is clicked with edits enabled", %{
      conn: conn,
      author: author,
      project: project
    } do
      attrs = %{
        id: "test_component",
        scopes: [:authoring],
        source_id: project.id,
        source_type: :project,
        source: project,
        current_author: author,
        edits_enabled: true
      }

      {:ok, lcd, _html} = live_component_isolated(conn, ScopedFeatureFlagsComponent, attrs)

      # Should have an Enable button for mcp_authoring
      assert has_element?(lcd, "button", "Enable")

      # Click enable button for mcp_authoring
      button = element(lcd, "button[phx-value-feature='mcp_authoring'][phx-value-enabled='true']")
      render_click(button)

      # Feature should now be enabled
      assert ScopedFeatureFlags.enabled?(:mcp_authoring, project)
    end

    test "shows feature scopes correctly", %{
      conn: conn,
      author: author,
      project: project
    } do
      attrs = %{
        id: "test_component",
        scopes: [:authoring, :both],
        source_id: project.id,
        source_type: :project,
        source: project,
        current_author: author
      }

      {:ok, lcd, _html} = live_component_isolated(conn, ScopedFeatureFlagsComponent, attrs)

      # Should show scope badges for features
      assert has_element?(lcd, "span.bg-blue-100", "authoring")
    end
  end

  describe "component parameter validation" do
    test "works with minimal required parameters", %{conn: conn} do
      author = insert(:author)
      project = insert(:project)

      attrs = %{
        id: "minimal_test",
        scopes: [:authoring],
        source_id: project.id,
        source_type: :project,
        source: project,
        current_author: author
      }

      {:ok, lcd, _html} = live_component_isolated(conn, ScopedFeatureFlagsComponent, attrs)
      assert has_element?(lcd, "div.scoped-feature-flags-component")
    end

    test "uses default title when not provided", %{conn: conn} do
      author = insert(:author)
      project = insert(:project)

      attrs = %{
        id: "default_title_test",
        scopes: [:authoring],
        source_id: project.id,
        source_type: :project,
        source: project,
        current_author: author
      }

      {:ok, lcd, _html} = live_component_isolated(conn, ScopedFeatureFlagsComponent, attrs)
      assert has_element?(lcd, "h3", "Feature Flags")
    end
  end
end
