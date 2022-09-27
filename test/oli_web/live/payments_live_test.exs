defmodule OliWeb.PaymentsLiveTest do
  use ExUnit.Case
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Delivery.Paywall
  alias Oli.Delivery.Paywall.Payment

  defp create_product(_conn) do
    product =
      insert(:section, type: :blueprint, requires_payment: true, amount: Money.new(:USD, 10))

    [product: product]
  end

  defp live_view_payments_route(product_slug) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.Products.PaymentsView, product_slug)
  end

  defp live_view_product_route(product_slug) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.Products.ProductsView, product_slug)
  end

  describe "user cannot access when is not logged in" do
    setup [:create_product]

    test "redirects to new session when accessing the payment view", %{
      conn: conn,
      product: product
    } do
      product_slug = product.slug

      redirect_path =
        "/authoring/session/new?request_path=%2Fauthoring%2Fproducts%2F#{product_slug}%2Fpayments"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_payments_route(product_slug))
    end
  end

  describe "user cannot access when is logged in as author of another project and is not a system administrator" do
    setup [:author_project_conn, :create_product]

    test "redirects to projects overview when accessing the payments view", %{
      conn: conn,
      product: product
    } do
      product_slug = product.slug
      redirect_path = "/authoring/projects"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_product_route(product_slug))
    end
  end

  describe "payments" do
    setup [:admin_conn, :create_product]

    test "loads correctly when there are no payments", %{conn: conn, product: product} do
      {:ok, view, _html} = live(conn, live_view_payments_route(product.slug))

      refute has_element?(view, ".table .table-striped .table-bordered .table-sm")
    end

    test "download button is disabled if no code has been created", %{
      conn: conn,
      product: product
    } do
      {:ok, view, _html} = live(conn, live_view_payments_route(product.slug))

      assert has_element?(
               view,
               "a[class*=\"disabled\"]",
               "Download last created"
             )
    end

    test "download button is enabled if any code has been created", %{
      conn: conn,
      product: product
    } do
      {:ok, view, _html} = live(conn, live_view_payments_route(product.slug))

      view
      |> element("button[phx-click=\"create\"]")
      |> render_click()

      refute has_element?(
               view,
               "a[class*=\"disabled\"]",
               "Download last created"
             )
    end

    test "When create codes button is clicked, codes are created and displayed in a table", %{
      conn: conn,
      product: product
    } do
      {:ok, view, _html} = live(conn, live_view_payments_route(product.slug))

      # Test that before I click the create code button, the table has no rows
      assert has_element?(view, "p", "None exist")

      # Simulate entering a number of payment codes to be created
      view
      |> element("input[phx-blur=\"change_count\"]")
      |> render_blur(%{value: "4"})

      # Simulate clicking on the button to create payment codes
      view
      |> element("button[phx-click=\"create\"]")
      |> render_click()

      # Get the payment codes generated for a current product
      [hd | _] = codes = Paywall.list_payments_by_count(product.slug, 4)
      code_to_test = Payment.to_human_readable(hd.code)

      # Test that payment codes were obtained.
      assert length(codes) == 4

      # Test that the table contains at least one code
      assert view
             |> element("tr:last-child > td:first-child > div")
             |> render() =~ "Code: <code>#{code_to_test}</code>"
    end
  end
end
