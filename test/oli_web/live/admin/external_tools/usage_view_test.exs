defmodule OliWeb.Admin.ExternalTools.UsageViewTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Oli.Factory

  describe "UsageView" do
    setup [:admin_conn]

    setup do
      platform = insert(:platform_instance)
      section = insert(:section)

      insert(:lti_external_tool_activity_deployment,
        platform_instance: platform,
        section: section
      )

      %{platform: platform, section: section}
    end

    test "redirects if platform_instance_id is invalid", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/admin/external_tools/invalid/usage")
      assert_redirect(view, ~p"/admin/external_tools")
      assert Phoenix.Flash.get(view.assigns.flash, :error) =~ "does not exist"
    end

    test "renders table for valid platform_instance", %{
      conn: conn,
      platform: platform,
      section: section
    } do
      {:ok, view, html} = live(conn, ~p"/admin/external_tools/#{platform.id}/usage")

      assert html =~ "Usage Count: Course Sections"
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
