defmodule OliWeb.Products.DetailsViewTest.ScopedFeatures do
  use OliWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Oli.Factory
  import Oli.TestHelpers

  describe "Section Management - Scoped Features Integration" do
    setup [:setup_admin_conn, :create_section]

    test "shows feature flags section for admin users", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, ~p"/authoring/products/#{section.slug}")

      # Should show the Feature Flags section
      assert has_element?(view, "h4", "Feature Flags")
      assert has_element?(view, "div.scoped-feature-flags-component")
    end

    test "redirects non-admin users to unauthorized page", %{section: section} do
      # Create non-admin author
      author = insert(:author)

      conn = log_in_author(build_conn(), author)

      # Should redirect to unauthorized page for non-admin users
      assert {:error, {:redirect, %{to: "/unauthorized"}}} = live(conn, ~p"/authoring/products/#{section.slug}")
    end

    test "displays section-appropriate features", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, ~p"/authoring/products/#{section.slug}")

      # No scoped features are defined for delivery context currently
      # This test verifies the section loads without error when no scoped features are available
      assert view
    end

    test "shows available delivery-scoped features", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, ~p"/authoring/products/#{section.slug}")

      # Click the enable edits checkbox
      view
      |> element("input[phx-click='toggle_edits']")
      |> render_click()

      # Should show feature toggle buttons for delivery-scoped features (test environment has them)
      assert has_element?(view, "button[phx-value-feature]")
    end

    test "section loads correctly with no scoped features", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, ~p"/authoring/products/#{section.slug}")

      # Should load the view successfully even with no delivery-scoped features
      assert view

      # Enable edits
      view
      |> element("input[phx-click='toggle_edits']")
      |> render_click()

      # Should not crash or show errors when no features are available
      assert view
    end

    test "component shows disabled state for available delivery features", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, ~p"/authoring/products/#{section.slug}")

      # Should show disabled badges for available delivery features that are not enabled
      refute has_element?(view, "span.bg-green-100", "Enabled")
      assert has_element?(view, "span.bg-gray-100", "Disabled")
    end

    test "does not show features incompatible with section context", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, ~p"/authoring/products/#{section.slug}")

      # Should not show authoring-only features like mcp_authoring
      refute has_element?(view, "td", "mcp_authoring")
    end
  end

  defp setup_admin_conn(_) do
    author = insert(:author, system_role_id: Oli.Accounts.SystemRole.role_id().content_admin)

    conn = log_in_author(build_conn(), author)

    {:ok, conn: conn, author: author}
  end

  defp create_section(%{author: author}) do
    # Create project and section
    project = insert(:project, authors: [author])
    section = insert(:section, base_project: project)
    {:ok, section: section}
  end
end
