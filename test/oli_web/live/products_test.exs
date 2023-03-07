defmodule OliWeb.ProductsLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory
  import Mox

  alias Oli.Delivery.Sections
  alias OliWeb.Router.Helpers, as: Routes

  defp live_view_details_route(product_slug) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.Products.DetailsView, product_slug)
  end

  defp create_product(_conn) do
    product =
      insert(:section, type: :blueprint, requires_payment: true, amount: Money.new(:USD, 10))

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

      assert has_element?(
               view,
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Products.Payments.Discounts.ProductsIndexView, product.slug)}\"]"
             )
    end
  end

  describe "product overview image upload" do
    setup [:admin_conn, :create_product]

    test "displays the current image", %{conn: conn} do
      product =
        insert(:section, type: :blueprint, cover_image: "https://example.com/some-image-url.png")

      {:ok, view, _html} = live(conn, live_view_details_route(product.slug))

      assert view
             |> element("#img-preview img")
             |> render() =~ "src=\"https://example.com/some-image-url.png\""
    end

    test "submit button is disabled if no file has been uploaded", %{conn: conn, product: product} do
      {:ok, view, _html} = live(conn, live_view_details_route(product.slug))

      assert view
             |> element("#img-upload-form button[type=\"submit\"]")
             |> render() =~ "disabled"
    end

    test "file is uploaded", %{conn: conn, product: product} do
      Oli.Test.MockAws
      |> expect(:request, 1, fn %ExAws.Operation.S3{} ->
        {:ok, %{status_code: 200}}
      end)

      {:ok, view, _html} = live(conn, live_view_details_route(product.slug))

      path = "assets/static/images/course_default.jpg"

      image =
        file_input(view, "#img-upload-form", :cover_image, [
          %{
            last_modified: 1_594_171_879_000,
            name: "myfile.jpeg",
            content: File.read!(path),
            type: "image/jpeg"
          }
        ])

      assert render_upload(image, "myfile.jpeg") =~ "100%"

      # submit button is enabled if a file has been uploaded
      refute view
             |> element("#img-upload-form button[type=\"submit\"]")
             |> render() =~ "disabled"

      # submitting displays new image
      assert view
             |> element("#img-upload-form")
             |> render_submit(%{})

      assert view
             |> render() =~ "<img id=\"current-product-img\""
    end

    test "canceling an upload restores previous rendered image", %{conn: conn} do
      current_image = "https://example.com/some-image-url.png"
      product = insert(:section, type: :blueprint, cover_image: current_image)

      {:ok, view, _html} = live(conn, live_view_details_route(product.slug))

      path = "assets/static/images/course_default.jpg"

      image =
        file_input(view, "#img-upload-form", :cover_image, [
          %{
            last_modified: 1_594_171_879_000,
            name: "myfile.jpeg",
            content: File.read!(path),
            type: "image/jpeg"
          }
        ])

      assert render_upload(image, "myfile.jpeg") =~ "100%"

      assert view
             |> has_element?("#img-upload-form div[role=\"progressbar\"")

      view
      |> element("button[phx-click=\"cancel_upload\"]")
      |> render_click()

      assert view
             |> render() =~ "<img id=\"current-product-img\" src=\"#{current_image}\""
    end
  end
end
