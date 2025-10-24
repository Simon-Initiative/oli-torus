defmodule OliWeb.AdminWorkspaceLayoutControllerTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  alias Floki

  describe "workspace layout applied to admin controllers" do
    setup [:admin_conn]

    test "invite page renders workspace shell and breadcrumb", %{conn: conn} do
      conn = get(conn, ~p"/admin/invite")
      html = html_response(conn, 200)

      assert html =~ "id=\"header\""
      assert html =~ "id=\"curriculum-back\""
      assert html =~ "Invite New Authors"
      assert_admin_nav_active(html)
    end

    test "brands index renders workspace shell and breadcrumb", %{conn: conn} do
      conn = get(conn, ~p"/admin/brands")
      html = html_response(conn, 200)

      assert html =~ "id=\"header\""
      assert html =~ "id=\"curriculum-back\""
      assert html =~ "Manage Brands"
      assert_admin_nav_active(html)
    end

    test "manage activities renders workspace shell and breadcrumb", %{conn: conn} do
      conn = get(conn, ~p"/admin/manage_activities")
      html = html_response(conn, 200)

      assert html =~ "id=\"header\""
      assert html =~ "id=\"curriculum-back\""
      assert html =~ "Manage Activities"
      assert_admin_nav_active(html)
    end
  end

  describe "ingest live view bootstrapping" do
    setup [:admin_conn]

    test "redirects to ingest upload when no archive exists", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/admin/ingest/upload"}}} =
               live(conn, ~p"/admin/ingest/process")
    end
  end

  defp assert_admin_nav_active(html) do
    doc = Floki.parse_document!(html)

    nav_link =
      doc
      |> Floki.find("#desktop_admin_workspace_nav_link div.relative")
      |> List.first()

    refute nav_link == nil

    class =
      nav_link
      |> elem(1)
      |> Enum.into(%{})
      |> Map.get("class", "")

    assert String.contains?(class, "bg-[#FFE5C2]")
  end
end
