defmodule OliWeb.Admin.ExternalTools.DetailsViewTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Oli.Factory
  import Oli.TestHelpers

  alias Oli.Lti.PlatformExternalTools
  alias Oli.Repo

  def insert_lti_tool(_) do
    institution = insert(:institution)

    {:ok, {pi, ar, _}} =
      PlatformExternalTools.register_lti_external_tool_activity(%{
        "name" => "Original Tool",
        "description" => "A test tool",
        "target_link_uri" => "https://example.com/launch",
        "client_id" => "abc-123",
        "login_url" => "https://example.com/login",
        "keyset_url" => "https://example.com/keyset",
        "redirect_uris" => "https://example.com/redirect",
        "institution_id" => institution.id
      })

    %{institution: institution, platform_instance: pi, activity_registration: ar}
  end

  describe "user cannot access when is not logged in" do
    setup [:insert_lti_tool]

    test "redirects to new session when accessing the details view", %{
      conn: conn,
      platform_instance: pi
    } do
      {:error, {:redirect, %{to: "/authors/log_in"}}} =
        live(conn, ~p"/admin/external_tools/#{pi.id}/details")
    end
  end

  describe "user cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn, :insert_lti_tool]

    test "returns forbidden when accessing the details view", %{conn: conn, platform_instance: pi} do
      conn = get(conn, ~p"/admin/external_tools/#{pi.id}/details")

      assert redirected_to(conn, 302) ==
               "/workspaces/course_author"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "You are not authorized to access this page."
    end
  end

  describe "new external tool" do
    setup [:admin_conn, :insert_lti_tool]

    test "shows the form in read-only mode by default", %{conn: conn, platform_instance: pi} do
      {:ok, view, _html} = live(conn, ~p"/admin/external_tools/#{pi.id}/details")

      # Check that the form is in read-only mode
      assert has_element?(view, "button", "Edit Details")
      refute has_element?(view, "fieldset", "[disabled]")
    end

    test "updates the tool details successfully", %{conn: conn, platform_instance: pi} do
      {:ok, view, _html} = live(conn, ~p"/admin/external_tools/#{pi.id}/details")

      # Click the edit button to enable edit mode
      view
      |> element("button", "Edit Details")
      |> render_click()

      # Fill in the form fields with new data
      view
      |> form("#tool_form", %{
        "tool_form" => %{
          "name" => "Updated Tool",
          "description" => "An updated external tool",
          "client_id" => "updated_tool_client_id",
          "target_link_uri" => "https://example.com/launch_updated",
          "login_url" => "https://example.com/login_updated",
          "keyset_url" => "https://example.com/jwks_updated",
          "redirect_uris" => "https://example.com/redirect_updated",
          "custom_params" => "param1=value1_updated&param2=value2_updated"
        }
      })
      |> render_submit()

      # Check that the success message is displayed
      assert has_element?(
               view,
               "#flash",
               "You have successfully updated the LTI 1.3 External Tool."
             )

      platform_instance = PlatformExternalTools.get_platform_instance(pi.id)
      assert platform_instance.name == "Updated Tool"

      # Check that the form is no longer in edit mode
      refute has_element?(view, "button", "Save")
      assert has_element?(view, "button", "Edit Details")
    end

    test "cancel button returns to read-only mode", %{conn: conn, platform_instance: pi} do
      {:ok, view, _html} = live(conn, ~p"/admin/external_tools/#{pi.id}/details")

      # Click the edit button to enable edit mode
      view
      |> element("button", "Edit Details")
      |> render_click()

      # Click the cancel button to return to read-only mode
      view
      |> element("button", "Cancel")
      |> render_click()

      # Check that the form is in read-only mode
      assert has_element?(view, "button", "Edit Details")
      refute has_element?(view, "fieldset", "[disabled]")
    end

    test "shows error message for missing required fields", %{conn: conn, platform_instance: pi} do
      {:ok, view, _html} = live(conn, ~p"/admin/external_tools/#{pi.id}/details")

      # Click the edit button to enable edit mode
      view
      |> element("button", "Edit Details")
      |> render_click()

      # Fill in the form fields with missing required fields
      view
      |> form("#tool_form", %{
        "tool_form" => %{
          "name" => nil,
          "description" => "An updated external tool",
          "client_id" => "updated_tool_client_id",
          "target_link_uri" => "https://example.com/launch_updated",
          "login_url" => "https://example.com/login_updated",
          "keyset_url" => "https://example.com/jwks_updated",
          "redirect_uris" => "https://example.com/redirect_updated",
          "custom_params" => "param1=value1_updated&param2=value2_updated"
        }
      })
      |> render_submit()

      # Check that the error message is displayed
      assert has_element?(
               view,
               "#flash",
               "One or more of the required fields is missing; please check your input."
             )
    end

    test "shows error message for duplicate client_id", %{conn: conn, platform_instance: pi} do
      # Create an existing platform instance with a specific client_id
      existing_platform_instance = insert(:platform_instance, client_id: "existing_client_id")

      {:ok, view, _html} = live(conn, ~p"/admin/external_tools/#{pi.id}/details")

      # Click the edit button to enable edit mode
      view
      |> element("button", "Edit Details")
      |> render_click()

      # Fill in the form fields with the same client_id
      view
      |> form("#tool_form", %{
        "tool_form" => %{
          "name" => "Updated Tool",
          "description" => "An updated external tool",
          "client_id" => existing_platform_instance.client_id,
          "target_link_uri" => "https://example.com/launch_updated",
          "login_url" => "https://example.com/login_updated",
          "keyset_url" => "https://example.com/jwks_updated",
          "redirect_uris" => "https://example.com/redirect_updated",
          "custom_params" => "param1=value1_updated&param2=value2_updated"
        }
      })
      |> render_submit()

      # Check that the error message is displayed
      assert has_element?(
               view,
               "#flash",
               "The client ID already exists and must be unique."
             )
    end

    test "shows error message for non-existent platform instance", %{
      conn: conn,
      platform_instance: pi
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/external_tools/#{pi.id}/details")

      # Click the edit button to enable edit mode
      view
      |> element("button", "Edit Details")
      |> render_click()

      # Remove the existing platform instance from the database
      PlatformExternalTools.get_platform_instance(pi.id)
      |> Repo.delete()

      # Fill in the form fields with the existing platform instance ID
      view
      |> form("#tool_form", %{
        "tool_form" => %{
          "name" => "Updated Tool",
          "description" => "An updated external tool",
          "client_id" => "updated_tool_client_id",
          "target_link_uri" => "https://example.com/launch_updated",
          "login_url" => "https://example.com/login_updated",
          "keyset_url" => "https://example.com/jwks_updated",
          "redirect_uris" => "https://example.com/redirect_updated",
          "custom_params" => "param1=value1_updated&param2=value2_updated"
        }
      })
      |> render_submit()

      # Check that the error message is displayed
      assert has_element?(
               view,
               "#flash",
               "This platform instance no longer exists or couldn’t be found."
             )
    end

    test "flash message is cleared when the clear button is clicked", %{
      conn: conn,
      platform_instance: pi
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/external_tools/#{pi.id}/details")

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
               "You have successfully updated the LTI 1.3 External Tool."
             )

      # Click the clear button to remove the error message
      view
      |> element(~s"button[phx-click=clear-custom-flash]")
      |> render_click()

      # Check that the error message is no longer displayed
      refute has_element?(view, "#flash")
    end

    test "redirects to external tools view when LTI tool does not exist", %{
      conn: conn
    } do
      {:error,
       {:redirect,
        %{
          to: "/admin/external_tools",
          flash: %{"error" => "The LTI Tool you are trying to view does not exist."}
        }}} = live(conn, ~p"/admin/external_tools/12345/details")
    end
  end
end
