defmodule OliWeb.Admin.ExternalTools.DetailsViewTest do
  use OliWeb.ConnCase, async: true

  import Ecto.Query
  import Phoenix.LiveViewTest
  import Oli.Factory
  import Oli.TestHelpers

  alias Oli.Accounts.SystemRole
  alias Oli.Lti.PlatformExternalTools
  alias Oli.Lti.PlatformExternalTools.LtiExternalToolProjectGrant
  alias Oli.Repo

  def insert_lti_tool(_) do
    institution = insert(:institution)

    {:ok, {pi, ar, dep}} =
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

    %{institution: institution, platform_instance: pi, activity_registration: ar, deployment: dep}
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
      |> element("button[role=\"cancel_edit\"]", "Cancel")
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

    test "enables the tool for project and course section use", %{
      conn: conn,
      platform_instance: pi,
      deployment: dep
    } do
      PlatformExternalTools.update_lti_external_tool_activity_deployment(dep, %{status: :disabled})

      {:ok, view, _html} = live(conn, ~p"/admin/external_tools/#{pi.id}/details")

      # Check that the tool is disabled
      assert has_element?(view, "#toggle_tool_switch_checkbox[data-checked=\"false\"]")

      view
      |> element("#toggle_tool_switch")
      |> render_change()

      # Check that the tool is enabled
      assert has_element?(view, "#toggle_tool_switch_checkbox[data-checked=\"true\"]")

      assert PlatformExternalTools.get_lti_external_tool_activity_deployment!(dep.deployment_id).status ===
               :enabled
    end

    test "soft deletes the tool when the delete button is clicked", %{
      conn: conn,
      platform_instance: pi,
      deployment: dep
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/external_tools/#{pi.id}/details")

      # Delete tool after accepting the modal warning
      view
      |> element("button[id=\"delete_tool_modal-confirm\"]", "Delete Tool")
      |> render_click()

      assert_redirected(view, ~p"/admin/external_tools")

      assert PlatformExternalTools.get_lti_external_tool_activity_deployment!(dep.deployment_id).status ===
               :deleted
    end

    test "does not show toggle enable, delete, or edit buttons for deleted tools", %{
      conn: conn,
      platform_instance: pi,
      deployment: dep
    } do
      Oli.Lti.PlatformExternalTools.update_lti_external_tool_activity_deployment(dep, %{
        status: :deleted
      })

      {:ok, view, _html} = live(conn, ~p"/admin/external_tools/#{pi.id}/details")

      refute has_element?(view, "button", "Edit Details")
      refute has_element?(view, "#toggle_switch_form")
      refute has_element?(view, "button[role='delete tool']")
      refute has_element?(view, "#availability_form")
      refute has_element?(view, "#tool_grants")
    end
  end

  describe "availability and project access" do
    setup [:admin_conn, :insert_lti_tool]

    test "Public saves at once, Private is confirmed first, and projects with access show only while Private",
         %{conn: conn, platform_instance: pi, deployment: dep} do
      project = insert(:project, title: "Granted Chemistry")
      {:ok, _} = PlatformExternalTools.grant_project(dep, project.id)

      {:ok, view, _html} = live(conn, ~p"/admin/external_tools/#{pi.id}/details")

      assert has_element?(view, "fieldset#availability-0 legend", "Availability")
      assert has_element?(view, "#availability-0-private[checked]")
      refute has_element?(view, "#availability-0-public[checked]")

      assert has_element?(
               view,
               "#availability_help",
               "Only the projects below can add this tool."
             )

      assert has_element?(view, "#tool_grants", "Granted Chemistry")

      view |> form("#availability_form", %{availability: "public"}) |> render_change()

      assert reload(dep).availability == :public
      refute has_element?(view, "#make_private_modal")
      assert has_element?(view, "#flash", "made the LTI 1.3 External Tool public")
      assert has_element?(view, "#availability-0-public[checked]")
      assert has_element?(view, "#availability_help", "Any project can add this tool.")
      refute has_element?(view, "#tool_grants")

      view |> form("#availability_form", %{availability: "private"}) |> render_change()

      assert has_element?(view, "#make_private_modal", "Make Original Tool private?")
      assert has_element?(view, "#availability-0-private[checked]")
      assert reload(dep).availability == :public

      view |> element("#make_private_modal button", "Cancel") |> render_click()

      refute has_element?(view, "#make_private_modal")
      assert has_element?(view, "#availability-0-public[checked]")
      assert reload(dep).availability == :public

      view |> form("#availability_form", %{availability: "private"}) |> render_change()
      view |> element("#make_private_modal-confirm") |> render_click()

      assert reload(dep).availability == :private
      assert has_element?(view, "#flash", "made the LTI 1.3 External Tool private")
      assert has_element?(view, "#tool_grants", "Granted Chemistry")
    end

    test "grants a project found by the search and removes it", %{
      conn: conn,
      platform_instance: pi,
      deployment: dep
    } do
      chemistry = insert(:project, title: "Chemistry Target", slug: "chemistry_target")
      physics = insert(:project, title: "Physics Target", slug: "physics_target")

      {:ok, view, _html} = live(conn, ~p"/admin/external_tools/#{pi.id}/details")

      assert has_element?(view, "#no_grants", "No project can add this tool yet.")

      view |> form("#project_search_form", %{value: "chemistry"}) |> render_change()

      assert has_element?(view, "#search_results_table", "Chemistry Target")
      refute has_element?(view, "#search_results_table", "Physics Target")

      view |> form("#project_search_form", %{value: "target"}) |> render_change()

      view
      |> element("#search_results_table button[phx-value-id='#{chemistry.id}']", "Grant access")
      |> render_click()

      assert granted?(dep, chemistry)
      refute granted?(dep, physics)
      refute has_element?(view, "#no_grants")

      assert has_element?(
               view,
               "#granted_projects_table a[href='/workspaces/course_author/chemistry_target/overview']",
               "Chemistry Target"
             )

      assert has_element?(view, "#granted_projects_table", "ID: chemistry_target")
      refute has_element?(view, "#granted_projects_table", "Physics Target")

      assert has_element?(
               view,
               "#search_results_table button[phx-value-id='#{physics.id}']",
               "Grant access"
             )

      refute has_element?(view, "#search_results_table", "Chemistry Target")

      view
      |> element("#granted_projects_table button[phx-value-id='#{chemistry.id}']", "Remove")
      |> render_click()

      refute granted?(dep, chemistry)
      assert has_element?(view, "#no_grants")
      assert has_element?(view, "#search_results_table", "Chemistry Target")
    end

    test "keeps row ids unique when a grant removed elsewhere shows one project in both lists", %{
      conn: conn,
      platform_instance: pi,
      deployment: dep
    } do
      project = insert(:project, title: "Chemistry Target")
      {:ok, _} = PlatformExternalTools.grant_project(dep, project.id)
      {:ok, view, _html} = live(conn, ~p"/admin/external_tools/#{pi.id}/details")

      :ok = PlatformExternalTools.revoke_project(dep, project.id)
      view |> form("#project_search_form", %{value: "chemistry"}) |> render_change()

      assert has_element?(view, "#granted_projects_table tr#granted-#{project.id}")
      assert has_element?(view, "#search_results_table tr#result-#{project.id}")
    end

    test "keeps the two clear buttons' ids distinct when both filters have text", %{
      conn: conn,
      platform_instance: pi,
      deployment: dep
    } do
      project = insert(:project, title: "Chemistry Target")
      {:ok, _} = PlatformExternalTools.grant_project(dep, project.id)
      {:ok, view, _html} = live(conn, ~p"/admin/external_tools/#{pi.id}/details")

      view |> form("#granted_filter_form", %{value: "chemistry"}) |> render_change()
      view |> form("#project_search_form", %{value: "physics"}) |> render_change()

      assert has_element?(view, "button#reset_grants_filter")
      assert has_element?(view, "button#clear_project_search")
    end

    test "does not grant a project that stopped being active after the search", %{
      conn: conn,
      platform_instance: pi,
      deployment: dep
    } do
      project = insert(:project, title: "Chemistry Target")
      {:ok, view, _html} = live(conn, ~p"/admin/external_tools/#{pi.id}/details")
      view |> form("#project_search_form", %{value: "chemistry"}) |> render_change()

      project |> Ecto.Changeset.change(status: :deleted) |> Repo.update!()

      view
      |> element("#search_results_table button[phx-value-id='#{project.id}']", "Grant access")
      |> render_click()

      refute granted?(dep, project)
      assert has_element?(view, "#flash", "Chemistry Target is no longer active")
      refute has_element?(view, "#search_results_table", "Chemistry Target")
    end

    test "the search announces accurate outcomes in one persistent polite status", %{
      conn: conn,
      platform_instance: pi,
      deployment: dep
    } do
      [first | _] =
        for n <- 1..11 do
          insert(:project, title: "Zeta Course #{String.pad_leading("#{n}", 2, "0")}")
        end

      {:ok, view, _html} = live(conn, ~p"/admin/external_tools/#{pi.id}/details")
      status = "#grant_search #project_search_status[role=status][aria-live=polite]"
      assert has_element?(view, status)

      assert view
             |> element(status)
             |> render()
             |> Floki.parse_fragment!()
             |> Floki.text()
             |> String.trim() == ""

      for {query, message} <- [
            {"missing course", "No matching projects."},
            {"Zeta Course 01", "1 matching project."},
            {"Zeta Course", "Showing the first 10 matches. Type more to narrow the search."}
          ] do
        html = view |> form("#project_search_form", %{value: query}) |> render_change()

        assert view
               |> element(status)
               |> render()
               |> Floki.parse_fragment!()
               |> Floki.text()
               |> String.trim() == message

        assert length(
                 Floki.find(
                   Floki.parse_document!(html),
                   "#grant_search [role=status], #grant_search [aria-live]"
                 )
               ) == 1

        refute has_element?(view, "#project_search_status table")
      end

      assert render(view) |> row_slugs("#search_results_table") |> length() == 10
      assert has_element?(view, "#more_results_notice", "Showing the first 10 matches.")

      {:ok, _} = PlatformExternalTools.grant_project(dep, first.id)
      html = view |> form("#project_search_form", %{value: "zeta course"}) |> render_change()
      assert html |> row_slugs("#search_results_table") |> length() == 10
      assert has_element?(view, status, "10 matching projects.")
      refute has_element?(view, "#more_results_notice")

      view |> element("#clear_project_search") |> render_click()
      assert has_element?(view, status)

      assert view
             |> element(status)
             |> render()
             |> Floki.parse_fragment!()
             |> Floki.text()
             |> String.trim() == ""

      refute has_element?(view, "#search_results_table")
    end

    test "lists projects with access 20 per page, sorted by title, with a filter", %{
      conn: conn,
      platform_instance: pi,
      deployment: dep
    } do
      for n <- 21..1//-1 do
        number = String.pad_leading("#{n}", 2, "0")
        project = insert(:project, title: "Alpha #{number}", slug: "alpha_#{number}")
        {:ok, _} = PlatformExternalTools.grant_project(dep, project.id)
      end

      {:ok, view, html} = live(conn, ~p"/admin/external_tools/#{pi.id}/details")

      first_page = row_slugs(html, "#granted_projects_table")
      assert length(first_page) == 20
      assert hd(first_page) == "alpha_01"

      html =
        view
        |> element("#granted_projects_table button[aria-label='Next page']")
        |> render_click()

      assert row_slugs(html, "#granted_projects_table") == ["alpha_21"]

      html = view |> element("#granted_projects_table th", "Project") |> render_click()
      assert html |> row_slugs("#granted_projects_table") |> hd() == "alpha_21"

      html = view |> form("#granted_filter_form", %{value: "alpha 07"}) |> render_change()
      assert row_slugs(html, "#granted_projects_table") == ["alpha_07"]

      html = view |> form("#granted_filter_form", %{value: "alpha_12"}) |> render_change()
      assert row_slugs(html, "#granted_projects_table") == ["alpha_12"]
    end
  end

  describe "availability and project access for an account admin" do
    setup [:account_admin_conn, :insert_lti_tool]

    for {availability, help} <- [
          {:public, "Any project can add this tool."},
          {:private,
           "Only the projects below can add this tool. Projects that already added it are not affected."}
        ] do
      @availability availability
      @help help
      test "#{availability} availability associates its help with the radio group", %{
        conn: conn,
        platform_instance: pi,
        deployment: dep
      } do
        {:ok, _} = PlatformExternalTools.set_availability(dep, @availability)
        {:ok, view, _html} = live(conn, ~p"/admin/external_tools/#{pi.id}/details")

        assert_availability_description(view, "availability-0", @help)
      end
    end

    test "read events refuse a demoted admin without disclosing new or hidden projects", %{
      conn: conn,
      account_admin: account_admin,
      platform_instance: pi,
      deployment: dep
    } do
      for n <- 1..21 do
        number = String.pad_leading("#{n}", 2, "0")
        project = insert(:project, title: "Cached #{number}", slug: "cached_#{number}")
        {:ok, _} = PlatformExternalTools.grant_project(dep, project.id)
      end

      searchable = insert(:project, title: "Searchable project")

      events = [
        {"search_projects", %{"value" => "Searchable"}},
        {"clear_project_search", %{}},
        {"filter_grants", %{"value" => "cached_21"}},
        {"reset_grants_filter", %{}},
        {"page_grants", %{"offset" => "20"}},
        {"sort_grants", %{}}
      ]

      for {event, params} <- events do
        set_role(Repo.reload!(account_admin), :account_admin)
        {:ok, view, _html} = live(conn, ~p"/admin/external_tools/#{pi.id}/details")
        render_click(view, "search_projects", %{"value" => "Searchable"})

        case event do
          "reset_grants_filter" ->
            render_click(view, "filter_grants", %{"value" => "cached_01"})

          _ ->
            :ok
        end

        before = view |> element("#tool_grants") |> render()
        render_click(view, event, params)
        refute has_element?(view, "#flash")

        case event do
          "search_projects" ->
            assert has_element?(view, "#search_results_table", searchable.title)

          "clear_project_search" ->
            refute has_element?(view, "#search_results_table")

          "filter_grants" ->
            assert row_slugs(render(view), "#granted_projects_table") == ["cached_21"]

          "reset_grants_filter" ->
            assert length(row_slugs(render(view), "#granted_projects_table")) == 20

          "page_grants" ->
            assert row_slugs(render(view), "#granted_projects_table") == ["cached_21"]

          "sort_grants" ->
            assert hd(row_slugs(render(view), "#granted_projects_table")) == "cached_21"
        end

        {:ok, view, _html} = live(conn, ~p"/admin/external_tools/#{pi.id}/details")
        render_click(view, "search_projects", %{"value" => "Searchable"})

        case event do
          "reset_grants_filter" ->
            render_click(view, "filter_grants", %{"value" => "cached_01"})

          _ ->
            :ok
        end

        assert view |> element("#tool_grants") |> render() == before
        refute has_element?(view, "#granted_projects_table", "Cached 21")
        set_role(account_admin, :author)
        new_project = insert(:project, title: "Searchable after demotion #{event}")
        html = render_click(view, event, params)

        assert has_element?(
                 view,
                 "#flash",
                 "Only account administrators can view or change who can use this tool."
               ),
               event

        refute html |> Floki.parse_document!() |> Floki.text() =~ new_project.title, event
        assert view |> element("#tool_grants") |> render() == before, event
      end
    end

    test "row action names distinguish equal titles and identify their own project", %{
      conn: conn,
      platform_instance: pi,
      deployment: dep
    } do
      projects =
        for slug <- ["shared_title_one", "shared_title_two"] do
          insert(:project, title: "Shared title", slug: slug)
        end

      {:ok, view, _html} = live(conn, ~p"/admin/external_tools/#{pi.id}/details")
      render_click(view, "search_projects", %{"value" => "Shared title"})

      for {event, label, table, prefix} <- [
            {"grant_project", "Grant access", "search_results_table", "result"},
            {"revoke_project", "Remove", "granted_projects_table", "granted"}
          ] do
        for project <- projects do
          selector = "##{table} tr##{prefix}-#{project.id} button"
          button = view |> element(selector) |> render() |> Floki.parse_fragment!()

          assert Floki.attribute(button, "aria-label") ==
                   ["#{label} for #{project.title} (#{project.slug})"]

          assert Floki.attribute(button, "phx-value-id") == [to_string(project.id)]
          assert Floki.attribute(button, "phx-click") == [event]
          assert button |> Floki.text() |> String.trim() == label
        end

        for project <- projects do
          view
          |> element("##{table} button[phx-value-id='#{project.id}']")
          |> render_click()
        end
      end

      for project <- projects, do: refute(granted?(dep, project))
    end

    test "stop being allowed once the author is no longer an account admin", %{
      conn: conn,
      account_admin: account_admin,
      platform_instance: pi,
      deployment: dep
    } do
      chemistry = insert(:project, title: "Chemistry Target")
      physics = insert(:project, title: "Physics Target")

      {:ok, view, _html} = live(conn, ~p"/admin/external_tools/#{pi.id}/details")
      view |> form("#project_search_form", %{value: "target"}) |> render_change()

      view
      |> element("#search_results_table button[phx-value-id='#{chemistry.id}']")
      |> render_click()

      assert granted?(dep, chemistry)

      set_role(account_admin, :content_admin)

      view
      |> element("#search_results_table button[phx-value-id='#{physics.id}']")
      |> render_click()

      refute granted?(dep, physics)

      assert has_element?(
               view,
               "#flash",
               "Only account administrators can view or change who can use this tool."
             )

      view
      |> element("#granted_projects_table button[phx-value-id='#{chemistry.id}']")
      |> render_click()

      assert granted?(dep, chemistry)

      view |> form("#availability_form", %{availability: "public"}) |> render_change()

      assert reload(dep).availability == :private
    end

    test "a refused change to Public renders the control again with the stored Private", %{
      conn: conn,
      account_admin: account_admin,
      platform_instance: pi,
      deployment: dep
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/external_tools/#{pi.id}/details")
      assert has_element?(view, "#availability-0-private[checked]")

      set_role(account_admin, :author)
      view |> form("#availability_form", %{availability: "public"}) |> render_change()

      assert reload(dep).availability == :private
      refute has_element?(view, "#availability-0-private")
      assert has_element?(view, "#availability-1-private[checked]")

      assert_availability_description(
        view,
        "availability-1",
        "Only the projects below can add this tool. Projects that already added it are not affected."
      )
    end

    test "a Private confirmed by an author who lost the role is not saved", %{
      conn: conn,
      account_admin: account_admin,
      platform_instance: pi,
      deployment: dep
    } do
      {:ok, _} = PlatformExternalTools.set_availability(dep, :public)
      {:ok, view, _html} = live(conn, ~p"/admin/external_tools/#{pi.id}/details")

      set_role(account_admin, :author)

      view |> form("#availability_form", %{availability: "private"}) |> render_change()
      view |> element("#make_private_modal-confirm") |> render_click()

      assert reload(dep).availability == :public

      assert has_element?(
               view,
               "#flash",
               "Only account administrators can view or change who can use this tool."
             )
    end
  end

  defp assert_availability_description(view, fieldset_id, help) do
    document = view |> render() |> Floki.parse_document!()
    fieldset = Floki.find(document, "fieldset##{fieldset_id}")

    assert Floki.attribute(fieldset, "aria-describedby") == ["availability_help"]
    assert [description] = Floki.find(document, "#availability_help")
    assert description |> Floki.text() |> String.trim() == help
  end

  defp reload(dep),
    do: PlatformExternalTools.get_lti_external_tool_activity_deployment!(dep.deployment_id)

  defp granted?(dep, project) do
    Repo.exists?(
      from g in LtiExternalToolProjectGrant,
        where: g.deployment_id == ^dep.deployment_id and g.project_id == ^project.id
    )
  end

  defp set_role(author, role) do
    author
    |> Ecto.Changeset.change(system_role_id: Map.fetch!(SystemRole.role_id(), role))
    |> Repo.update!()
  end

  # A filtered title is split into highlighted words, so rows are read by the slug in their link.
  defp row_slugs(html, table) do
    html
    |> Floki.parse_document!()
    |> Floki.find("#{table} tbody tr td:first-child a")
    |> Enum.flat_map(&Floki.attribute(&1, "href"))
    |> Enum.map(&(&1 |> String.split("/") |> Enum.at(-2)))
  end
end
