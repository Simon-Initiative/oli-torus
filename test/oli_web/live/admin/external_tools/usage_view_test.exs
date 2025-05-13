defmodule OliWeb.Admin.ExternalTools.UsageViewTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Oli.Factory

  describe "UsageView" do
    setup [:admin_conn]

    setup do
      section = insert(:section)
      platform = insert(:platform_instance)

      lti_deployment =
        insert(:lti_external_tool_activity_deployment,
          platform_instance: platform
        )

      activity_registration =
        insert(:activity_registration,
          lti_external_tool_activity_deployment: lti_deployment
        )

      lti_activity_revision =
        insert(:revision,
          activity_type_id: activity_registration.id
        )

      lti_activity_resource = lti_activity_revision.resource

      lti_section_resource =
        insert(:section_resource,
          section: section,
          resource_id: lti_activity_resource.id,
          revision_id: lti_activity_revision.id
        )

      page_revision =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          activity_refs: [lti_activity_resource.id]
        )

      page_section_resource =
        insert(:section_resource,
          section: section,
          resource_id: page_revision.resource_id,
          revision_id: page_revision.id
        )

      %{
        section: section,
        platform: platform,
        lti_activity_resource: lti_activity_resource,
        lti_section_resource: lti_section_resource,
        page_section_resource: page_section_resource
      }
    end

    test "redirects if user is not logged in", %{conn: _conn, platform: platform} do
      assert {:error, {:redirect, %{to: "/authors/log_in"}}} =
               live(build_conn(), ~p"/admin/external_tools/#{platform.id}/usage")
    end

    test "redirects if user is not an admin", %{conn: _conn, platform: platform} do
      conn = log_in_author(build_conn(), insert(:author))

      assert {:error, {:redirect, %{to: "/workspaces/course_author"}}} =
               live(conn, ~p"/admin/external_tools/#{platform.id}/usage")
    end

    test "redirects if platform_instance_id is invalid", %{conn: conn} do
      {:error,
       {:redirect,
        %{
          to: "/admin/external_tools",
          flash: %{"error" => "The LTI Tool you are trying to view does not exist."}
        }}} = live(conn, ~p"/admin/external_tools/9999/usage")
    end

    test "renders table for valid platform_instance", %{
      conn: conn,
      platform: platform,
      section: section
    } do
      {:ok, view, html} = live(conn, ~p"/admin/external_tools/#{platform.id}/usage")

      assert html =~ "Usage Count: Course Sections"
      open_browser(view)
      assert has_element?(view, "table")
      assert has_element?(view, "td", section.title)
    end

    test "pagination and sorting updates table", %{conn: conn, platform: platform} do
      insert_list(3, :section)

      {:ok, view, _html} =
        live(conn, ~p"/admin/external_tools/#{platform.id}/usage?sort_by=title&sort_order=asc")

      assert has_element?(view, "table")
    end
  end
end
