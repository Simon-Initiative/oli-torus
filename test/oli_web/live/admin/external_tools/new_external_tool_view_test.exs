defmodule OliWeb.Admin.ExternalTools.NewExternalToolViewTest do
  use OliWeb.ConnCase, async: true

  import Ecto.Query, warn: false
  import Phoenix.LiveViewTest
  import Oli.Factory
  import Oli.TestHelpers

  alias Lti_1p3.DataProviders.EctoProvider.PlatformInstance

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

      # get id of the newly created platform instance
      platform_instance =
        PlatformInstance
        |> where([p], p.client_id == "new_tool_client_id")
        |> Oli.Repo.one()

      # Check that the view was successfully redirected to the details view
      assert_redirect(
        view,
        ~p"/admin/external_tools/#{platform_instance.id}/details"
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
