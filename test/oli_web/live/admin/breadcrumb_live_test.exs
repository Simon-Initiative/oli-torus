defmodule OliWeb.Admin.BreadcrumbLiveTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "admin workspace breadcrumbs" do
    setup [:admin_conn]

    test "products view renders shared breadcrumb bar with admin back-link", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/products")

      html = render(view)

      assert html =~ ~s(nav class="breadcrumb-bar)
      assert html =~ "dark:border-neutral-800"
      assert html =~ "Products"
      assert html =~ ~s(href="/admin")
    end

    test "xapi pipeline view exposes breadcrumb trail", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/xapi")

      html = render(view)

      assert html =~ "XAPI Upload Pipeline"
      assert html =~ ~s(href="/admin")
      assert html =~ "dark:border-neutral-800"
    end
  end

  describe "community workspace breadcrumbs" do
    setup [:admin_conn]

    test "community index inherits admin breadcrumb trail", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/authoring/communities")

      html = render(view)

      assert html =~ ~s(nav class="breadcrumb-bar)
      assert html =~ "Communities"
      assert html =~ ~s(href="/admin")
      assert html =~ "dark:border-neutral-800"
    end
  end
end
