defmodule OliWeb.PaymentsLiveTest do
  use ExUnit.Case
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Delivery.Paywall.Payment

  defp create_product(_conn) do
    product =
      insert(:section, type: :blueprint, requires_payment: true, amount: Money.new(:USD, 10))

    [product: product]
  end

  defp live_view_payments_route(product_slug) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.Products.PaymentsView, product_slug)
  end

  @live_view_payment_route Routes.live_path(
                             OliWeb.Endpoint,
                             OliWeb.Products.PaymentsView,
                             "test_product"
                           )

  @live_view_product_route Routes.live_path(
                             OliWeb.Endpoint,
                             OliWeb.Products.ProductsView,
                             "test_product"
                           )

  describe "user cannot access when is not logged in" do
    test "redirects to new session when accessing the index view", %{conn: conn} do
      {:error,
       {:redirect,
        %{
          to:
            "/authoring/session/new?request_path=%2Fauthoring%2Fproducts%2Ftest_product%2Fpayments"
        }}} = live(conn, @live_view_payment_route)
    end
  end

  describe "user cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn]

    test "redirects to projects overview when accessing the payments view", %{conn: conn} do
      {:error, {:redirect, %{to: "/authoring/projects"}}} = live(conn, @live_view_product_route)
    end
  end

  describe "payments" do
    setup [:admin_conn, :create_product]

    test "loads correctly when there are no payments", %{conn: conn, product: product} do
      {:ok, view, _html} = live(conn, live_view_payments_route(product.slug))

      assert has_element?(view, "button", "Create")
      assert has_element?(view, "a", "Download last created")
      assert has_element?(view, "input[phx-change=\"change_search\"]")
      assert has_element?(view, "p", "None exist")
      refute has_element?(view, ".table .table-striped .table-bordered .table-sm")
    end

    test "download button is disabled if no code has been created", %{
      conn: conn,
      product: product
    } do
      {:ok, view, _html} = live(conn, live_view_payments_route(product.slug))

      assert view
             |> element("a")
             |> render() =~ "disabled"
    end

    test "download button is enabled if any code has been created", %{
      conn: conn,
      product: product
    } do
      {:ok, view, _html} = live(conn, live_view_payments_route(product.slug))

      view
      |> element("button[phx-click=\"create\"]")
      |> render_click()

      refute view
             |> element("a", "Download last created")
             |> render() =~ "disabled"
    end

    test "When create codes button is clicked, codes are created and listing in a table", %{
      conn: conn,
      product: product
    } do
      {:ok, view, _html} = live(conn, live_view_payments_route(product.slug))

      view
      |> element("button[phx-click=\"create\"]")
      |> render_click()

      assert has_element?(view, ".table")
      assert has_element?(view, "td")
    end
  end
end
