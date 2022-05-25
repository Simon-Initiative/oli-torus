defmodule OliWeb.ProductsLiveTest do
  use ExUnit.Case
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Delivery.Sections

  defp live_view_details_route(product_slug) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.Products.DetailsView, product_slug)
  end

  defp create_product(_conn) do
    product = insert(:section, type: :blueprint, requires_payment: true, amount: Money.new(:USD, 10))

    [product: product]
  end

  describe "product overview content settings" do
    setup [:admin_conn, :create_product]

    test "save event updates curriculum numbering visibility", %{conn: conn, product: product} do
      {:ok, view, _html} = live(conn, live_view_details_route(product.slug))

      assert view
        |> element("#section_display_curriculum_item_numbering")
        |> render() =~ "checked"

      view
        |> element("#content-form form[phx-change=\"save\"")
        |> render_change(%{
          "section" => %{"display_curriculum_item_numbering" => "false"}
        })

      updated_section = Sections.get_section!(product.id)
      refute updated_section.display_curriculum_item_numbering

      refute view
        |> element("#section_display_curriculum_item_numbering")
        |> render() =~ "checked"
    end
  end

  describe "user cannot access when is not logged in" do
    setup [:create_product]

    test "redirects to new session when accessing the product detail view", %{
      conn: conn,
      product: product
    } do
      product_slug = product.slug

      redirect_path =
        "/authoring/session/new?request_path=%2Fauthoring%2Fproducts%2F#{product_slug}"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_details_route(product_slug))
    end
  end

  describe "user cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn, :create_product]

    test "redirects to new session when accessing the section overview view", %{
      conn: conn,
      product: product
    } do
      conn = get(conn, live_view_details_route(product.slug))

      redirect_path = "/unauthorized"
      assert redirected_to(conn, 302) =~ redirect_path
    end
  end

  describe "details live view" do
    setup [:admin_conn, :create_product]

    test "returns 404 when product not exists", %{conn: conn} do
      conn = get(conn, live_view_details_route("not_exists"))

      redirect_path = "/not_found"
      assert redirected_to(conn, 302) =~ redirect_path
    end

    test "loads product data correctly", %{conn: conn, product: product} do
      {:ok, view, _html} = live(conn, live_view_details_route(product.slug))

      assert render(view) =~ "Details"
      assert render(view) =~ "The Product title and description"
      assert has_element?(view, "input[value=\"#{product.title}\"]")
      assert has_element?(view, "input[name=\"section[pay_by_institution]\"]")
      assert has_element?(view, "a[href=\"#{Routes.discount_path(OliWeb.Endpoint, :product, product.slug)}\"]")
    end
  end
end
