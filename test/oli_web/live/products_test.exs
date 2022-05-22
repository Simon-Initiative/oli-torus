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
    product = insert(:section, type: :blueprint)

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
end
