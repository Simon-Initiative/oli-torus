defmodule OliWeb.Admin.ExternalTools.UsageViewTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Oli.Factory

  describe "UsageView" do
    setup [:admin_conn]

    setup do
      section = insert(:section, type: :enrollable, title: "AAA")
      section2 = insert(:section, type: :enrollable, title: "ZZZ")
      lti_deployment = insert(:lti_external_tool_activity_deployment)

      activity_registration =
        insert(:activity_registration,
          lti_external_tool_activity_deployment: lti_deployment
        )

      lti_activity_revision =
        insert(:revision,
          activity_type_id: activity_registration.id
        )

      lti_activity_resource = lti_activity_revision.resource

      insert(:section_resource,
        section: section,
        resource_id: lti_activity_resource.id,
        revision_id: lti_activity_revision.id,
        activity_type_id: activity_registration.id
      )

      insert(:section_resource,
        section: section2,
        resource_id: lti_activity_resource.id,
        revision_id: lti_activity_revision.id,
        activity_type_id: activity_registration.id
      )

      %{
        section: section,
        section2: section2,
        platform: lti_deployment.platform_instance
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
      section: section,
      section2: section2
    } do
      {:ok, view, html} = live(conn, ~p"/admin/external_tools/#{platform.id}/usage")

      assert html =~ "Usage Count: Course Sections"
      assert has_element?(view, "table")
      assert has_element?(view, "td", section.title)
      assert has_element?(view, "td", section2.title)

      assert has_element?(view, "th", "Title")
      assert has_element?(view, "th", "Type")
      assert has_element?(view, "th", "# Enrolled")
      assert has_element?(view, "th", "Cost")
      assert has_element?(view, "th", "Start")
      assert has_element?(view, "th", "End")
      assert has_element?(view, "th", "Status")
      assert has_element?(view, "th", "Base Project/Product")
      assert has_element?(view, "th", "Instructors")
      assert has_element?(view, "th", "Institution")
    end

    test "pagination and sorting updates table", %{conn: conn, platform: platform} do
      {:ok, view, _html} =
        live(conn, ~p"/admin/external_tools/#{platform.id}/usage?sort_by=title&sort_order=desc")

      titles =
        view
        |> render()
        |> Floki.parse_document!()
        |> Floki.find("table tbody tr td:nth-child(1)")
        |> Enum.map(&Floki.text/1)
        |> Enum.map(&String.trim/1)

      assert titles == ~w(ZZZ AAA)
    end
  end
end
