defmodule OliWeb.AdminWorkspaceLayoutControllerTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "workspace layout applied to admin controllers" do
    setup [:admin_conn]

    test "invite page renders workspace shell and breadcrumb", %{conn: conn} do
      conn = get(conn, ~p"/admin/invite")
      html = html_response(conn, 200)

      assert html =~ "id=\"header\""
      assert html =~ "id=\"curriculum-back\""
      assert html =~ "Invite New Authors"
    end

    test "brands index renders workspace shell and breadcrumb", %{conn: conn} do
      conn = get(conn, ~p"/admin/brands")
      html = html_response(conn, 200)

      assert html =~ "id=\"header\""
      assert html =~ "id=\"curriculum-back\""
      assert html =~ "Manage Brands"
    end

    test "manage activities renders workspace shell and breadcrumb", %{conn: conn} do
      conn = get(conn, ~p"/admin/manage_activities")
      html = html_response(conn, 200)

      assert html =~ "id=\"header\""
      assert html =~ "id=\"curriculum-back\""
      assert html =~ "Manage Activities"
    end
  end

  describe "ingest live view bootstrapping" do
    setup [:admin_conn]

    test "redirects to ingest upload when no archive exists", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/admin/ingest/upload"}}} =
               live(conn, ~p"/admin/ingest/process")
    end
  end
end
