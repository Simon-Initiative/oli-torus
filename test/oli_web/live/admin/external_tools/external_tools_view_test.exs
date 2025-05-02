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

      %{
        platform1: platform1,
        platform2: platform2,
        platform3: platform3,
        deployment1: deployment1,
        deployment2: deployment2,
        deployment3: deployment3
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
      |> element("input[type='checkbox']")
      |> render_click()

      # Should no longer show the disabled platform
      refute has_element?(view, "td", "Platform Three")
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

  describe "new external tool" do
    setup [:admin_conn]

    test "add button redirects to add new external tool view correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/external_tools")

      # Check that the new button redirects to the correct path
      assert view
             |> element("#button-new-tool")
             |> render_click()
             |> follow_redirect(conn, ~p"/admin/external_tools/new")
    end

    test "cancel button redirects to external tools view correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/external_tools/new")

      # Check that the cancel button redirects to the external tools view
      assert view
             |> element("a", "Cancel")
             |> render_click()
             |> follow_redirect(conn, ~p"/admin/external_tools")
    end

    test "a new external tool can be added", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/external_tools/new")

      # Fill in the form fields
      view
      |> form("#tool_form", %{
        "tool_form" => %{
          "name" => "New Tool",
          "description" => "A new external tool",
          "client_id" => "new_tool_client_id",
          "target_link_uri" => "https://example.com/launch",
          "login_url" => "https://example.com/login",
          "keyset_url" => "https://example.com/jwks",
          "redirect_uris" => "https://example.com/redirect",
          "custom_params" => "param1=value1&param2=value2"
        }
      })
      |> render_submit()

      # Check that the success message is displayed
      assert has_element?(
               view,
               "span",
               "Success!"
             )

      assert has_element?(
               view,
               "#flash",
               "You have successfully added an LTI 1.3 External Tool at the system level."
             )
    end

    test "a new external tool cannot be added with missing data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/external_tools/new")

      # Fill in the form fields with invalid data
      view
      |> form("#tool_form", %{
        "tool_form" => %{
          "name" => "name",
          "target_link_uri" => "some_uri",
          "redirect_uris" => "some_uri",
          "custom_params" => "some_param"
        }
      })
      |> render_submit()

      # Check that the error message is displayed
      assert has_element?(view, "span", "Missing Fields")
      assert has_element?(view, "#flash", "One or more of the required fields is missing")
    end

    test "cannot add a new external tool with duplicate client_id", %{conn: conn} do
      # Create an existing platform instance with a specific client_id
      existing_platform_instance = insert(:platform_instance, client_id: "existing_client_id")

      {:ok, view, _html} = live(conn, ~p"/admin/external_tools/new")

      # Fill in the form fields with the same client_id
      view
      |> form("#tool_form", %{
        "tool_form" => %{
          "name" => "New Tool",
          "description" => "A new external tool",
          "client_id" => existing_platform_instance.client_id,
          "target_link_uri" => "https://example.com/launch",
          "login_url" => "https://example.com/login",
          "keyset_url" => "https://example.com/jwks",
          "redirect_uris" => "https://example.com/redirect",
          "custom_params" => "param1=value1&param2=value2"
        }
      })
      |> render_submit()

      # Check that the error message is displayed
      assert has_element?(view, "span", "ID Already Exists")
      assert has_element?(view, "#flash", "The client ID already exists and must be unique.")
    end

    test "flash message is cleared when the clear button is clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/external_tools/new")

      # Fill in the form fields with valid data
      view
      |> form("#tool_form", %{
        "tool_form" => %{
          "name" => "New Tool",
          "description" => "A new external tool",
          "client_id" => "new_tool_client_id",
          "target_link_uri" => "https://example.com/launch",
          "login_url" => "https://example.com/login",
          "keyset_url" => "https://example.com/jwks",
          "redirect_uris" => "https://example.com/redirect",
          "custom_params" => "param1=value1&param2=value2"
        }
      })
      |> render_submit()

      # Check that the error message is displayed
      assert has_element?(
               view,
               "#flash",
               "You have successfully added an LTI 1.3 External Tool at the system level."
             )

      # Click the clear button to remove the error message
      view
      |> element(~s"button[phx-click=clear-custom-flash]")
      |> render_click()

      # Check that the error message is no longer displayed
      refute has_element?(view, "#flash")
    end

    test "flash message is cleared when the input changes", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/external_tools/new")

      # Fill in the form fields with duplicate client_id
      existing_platform_instance = insert(:platform_instance, client_id: "existing_client_id")

      view
      |> form("#tool_form", %{
        "tool_form" => %{
          "name" => "New Tool",
          "description" => "A new external tool",
          "client_id" => existing_platform_instance.client_id,
          "target_link_uri" => "https://example.com/launch",
          "login_url" => "https://example.com/login",
          "keyset_url" => "https://example.com/jwks",
          "redirect_uris" => "https://example.com/redirect",
          "custom_params" => "param1=value1&param2=value2"
        }
      })
      |> render_submit()

      # Check that the error message is displayed
      assert has_element?(
               view,
               "#flash",
               "The client ID already exists and must be unique."
             )

      # Simulate input change to clear the flash message
      view
      |> element(~s"form[phx-change=validate]")
      |> render_change(%{"name" => "New Name"})

      # Check that the flash message is no longer displayed
      refute has_element?(view, "#flash")
    end
  end
end
