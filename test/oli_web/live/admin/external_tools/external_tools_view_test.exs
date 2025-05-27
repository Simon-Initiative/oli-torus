defmodule OliWeb.Admin.ExternalTools.ExternalToolsViewTest do
  use OliWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Oli.Factory
  import Oli.TestHelpers

  describe "External Tools LiveView" do
    setup [:admin_conn]

    setup do
      # Create test platform instances with different names for sorting/filtering tests
      platform1 =
        insert(:platform_instance, %{
          name: "Platform One",
          description: "First platform"
        })

      platform2 =
        insert(:platform_instance, %{
          name: "Platform Two",
          description: "Second platform"
        })

      platform3 =
        insert(:platform_instance, %{
          name: "Platform Three",
          description: "Third platform"
        })

      platform4 =
        insert(:platform_instance, %{
          name: "Platform Four",
          description: "Fourth platform"
        })

      # Create deployments with different statuses
      deployment1 =
        insert(:lti_external_tool_activity_deployment, %{
          platform_instance: platform1,
          status: :enabled
        })

      deployment2 =
        insert(:lti_external_tool_activity_deployment, %{
          platform_instance: platform2,
          status: :enabled
        })

      deployment3 =
        insert(:lti_external_tool_activity_deployment, %{
          platform_instance: platform3,
          status: :disabled
        })

      deployment4 =
        insert(:lti_external_tool_activity_deployment, %{
          platform_instance: platform4,
          status: :deleted
        })

      %{
        platform1: platform1,
        platform2: platform2,
        platform3: platform3,
        platform4: platform4,
        deployment1: deployment1,
        deployment2: deployment2,
        deployment3: deployment3,
        deployment4: deployment4
      }
    end

    test "redirects if user is not logged in", %{conn: _conn} do
      conn = Phoenix.ConnTest.build_conn()

      assert {:error, {:redirect, %{to: "/authors/log_in"}}} =
               live(conn, ~p"/admin/external_tools")
    end

    test "redirects if user is not an admin", %{conn: _conn} do
      # Create a regular author
      author = insert(:author)
      conn = log_in_author(build_conn(), author)

      assert {:error, {:redirect, %{to: "/workspaces/course_author"}}} =
               live(conn, ~p"/admin/external_tools")
    end

    test "renders page for admin users", %{conn: conn, platform1: platform1} do
      {:ok, view, html} = live(conn, ~p"/admin/external_tools")

      # Check that the page renders with correct title
      assert html =~ "Manage LTI 1.3 External Tools"

      # Check that the search input is present
      assert has_element?(view, "input[phx-hook='TextInputListener']")

      # Check that the include_disabled checkbox is present
      assert has_element?(view, "input[type='checkbox']")

      # Check that the table is present with headers
      assert has_element?(view, "table")
      assert has_element?(view, "th", "Tool Name")
      assert has_element?(view, "th", "Description")

      # Check that at least one platform is shown
      assert has_element?(view, "td", platform1.name)
      assert has_element?(view, "td", platform1.description)
    end

    test "the view matches the url params", %{conn: conn} do
      # Test 1: Default view (no params) shows only enabled platforms
      {:ok, view, _html} = live(conn, ~p"/admin/external_tools")
      assert has_element?(view, "td", "Platform One")
      assert has_element?(view, "td", "Platform Two")
      assert has_element?(view, "td", "Platform Three")

      # Test 2: include_disabled=false shows only enabled platforms
      {:ok, view, _html} = live(conn, ~p"/admin/external_tools?include_disabled=false")
      assert has_element?(view, "td", "Platform One")
      assert has_element?(view, "td", "Platform Two")
      refute has_element?(view, "td", "Platform Three")

      # Test 3: text_search filters platforms
      {:ok, view, _html} = live(conn, ~p"/admin/external_tools?text_search=One")
      assert has_element?(view, "td", "Platform One")
      refute has_element?(view, "td", "Platform Two")
      refute has_element?(view, "td", "Platform Three")

      # Test 4: Sorting ascending by name
      {:ok, view, _html} =
        live(conn, ~p"/admin/external_tools?sort_by=name&sort_order=asc&include_disabled=true")

      platform_names =
        view
        |> render()
        |> Floki.parse_document!()
        |> Floki.find("td div")
        |> Floki.text(deep: false)
        |> String.split("\n", trim: true)
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&String.starts_with?(&1, "Platform"))

      assert platform_names == ["Platform One", "Platform Three", "Platform Two"]

      # Test 5: Sorting descending by name
      {:ok, view, _html} =
        live(conn, ~p"/admin/external_tools?sort_by=name&sort_order=desc&include_disabled=true")

      platform_names =
        view
        |> render()
        |> Floki.parse_document!()
        |> Floki.find("td div")
        |> Floki.text(deep: false)
        |> String.split("\n", trim: true)
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&String.starts_with?(&1, "Platform"))

      assert platform_names == ["Platform Two", "Platform Three", "Platform One"]

      # Test 6: Combining filters (text search + include_disabled)
      {:ok, view, _html} =
        live(conn, ~p"/admin/external_tools?text_search=Three&include_disabled=true")

      assert has_element?(view, "td", "Platform Three")
      refute has_element?(view, "td", "Platform One")
      refute has_element?(view, "td", "Platform Two")

      # Test 7: Combining filters (text search without include_disabled)
      {:ok, view, _html} =
        live(conn, ~p"/admin/external_tools?text_search=Three&include_disabled=false")

      refute has_element?(view, "td", "Platform Three")
      refute has_element?(view, "td", "Platform One")
      refute has_element?(view, "td", "Platform Two")
    end

    test "updates results when toggling include_disabled checkbox", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/external_tools?include_disabled=true")

      # Initially shows all platforms
      assert has_element?(view, "td", "Platform Three")

      # Click the checkbox to hide disabled platforms
      view
      |> element("input[type='checkbox'][id='include_disabled']")
      |> render_click()

      # Should no longer show the disabled platform
      refute has_element?(view, "td", "Platform Three")
    end

    test "updates results when toggling include_deleted checkbox", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/external_tools?include_deleted=true")

      # Initially shows all platforms
      assert has_element?(view, "td", "Platform One")
      assert has_element?(view, "td", "Platform Two")
      assert has_element?(view, "td", "Platform Three")
      assert has_element?(view, "td", "Platform Four")

      # Click the checkbox to hide deleted platforms
      view
      |> element("input[type='checkbox'][id='include_deleted']")
      |> render_click()

      # Should no longer show the deleted platform
      assert has_element?(view, "td", "Platform One")
      assert has_element?(view, "td", "Platform Two")
      assert has_element?(view, "td", "Platform Three")
      refute has_element?(view, "td", "Platform Four")
    end

    test "updates results when entering search text", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/external_tools")

      # Initially shows all enabled platforms
      assert has_element?(view, "td", "Platform One")
      assert has_element?(view, "td", "Platform Two")

      # Simulate text search change
      view
      |> element("input[phx-hook='TextInputListener']")
      |> render_hook("text_search_change", %{"value" => "Two"})

      # Should only show Platform Two
      refute has_element?(view, "td", "Platform One")
      assert has_element?(view, "td", "Platform Two")
    end
  end
end
