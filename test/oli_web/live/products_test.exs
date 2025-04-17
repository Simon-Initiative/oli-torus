defmodule OliWeb.ProductsLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory
  import Mox

  alias Oli.Delivery.{Paywall, Sections}
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Utils.Seeder
  alias Oli.Authoring.Course

  @live_view_all_products Routes.live_path(OliWeb.Endpoint, OliWeb.Products.ProductsView)

  defp live_view_products_route(project_slug) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.Products.ProductsView, project_slug)
  end

  defp live_view_details_route(product_slug) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.Products.DetailsView, product_slug)
  end

  defp create_product(_conn) do
    product =
      insert(:section, type: :blueprint, requires_payment: true, amount: Money.new(:USD, 10))

    [product: product]
  end

  defp create_product_with_payment_codes(_conn) do
    product =
      insert(:section, type: :blueprint, requires_payment: true, amount: Money.new(:USD, 10))

    stub_real_current_time()
    Paywall.create_payment_codes(product.slug, 20)

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

    test "save event updates apply_major_updates", %{conn: conn, product: product} do
      {:ok, view, _html} = live(conn, live_view_details_route(product.slug))

      refute view
             |> element("#section_apply_major_updates")
             |> render() =~ "checked"

      view
      |> element("#content-form form[phx-change=\"save\"")
      |> render_change(%{
        "section" => %{"apply_major_updates" => "true"}
      })

      updated_section = Sections.get_section!(product.id)
      assert updated_section.apply_major_updates

      assert view
             |> element("#section_display_curriculum_item_numbering")
             |> render() =~ "checked"
    end
  end

  describe "browse all products" do
    setup [:admin_conn, :create_product]

    test "shows all products list", %{conn: conn, product: product} do
      [{_, product_2} | _] = create_product(conn)

      {:ok, view, _html} = live(conn, @live_view_all_products)

      assert has_element?(view, "a", product.title)
      assert has_element?(view, "a", product_2.title)
    end

    test "search product by title", %{conn: conn, product: product} do
      [{_, product_2} | _] = create_product(conn)

      {:ok, view, _html} = live(conn, @live_view_all_products)

      assert has_element?(view, "a", product.title)
      assert has_element?(view, "a", product_2.title)

      render_hook(view, "text_search_change", %{value: product.title})

      assert has_element?(view, "a", product.title)
      refute has_element?(view, "a", product_2.title)

      view
      |> element("button[phx-click=\"text_search_reset\"]")
      |> render_click()

      assert has_element?(view, "a", product.title)
      assert has_element?(view, "a", product_2.title)
    end

    test "search product by base project title", %{conn: conn, product: product} do
      [{_, product_2} | _] = create_product(conn)

      {:ok, view, _html} = live(conn, @live_view_all_products)

      assert has_element?(view, "a", product.base_project.title)
      assert has_element?(view, "a", product_2.base_project.title)

      render_hook(view, "text_search_change", %{value: product_2.base_project.title})

      refute has_element?(view, "a", product.base_project.title)
      assert has_element?(view, "a", product_2.base_project.title)

      view
      |> element("button[phx-click=\"text_search_reset\"]")
      |> render_click()

      assert has_element?(view, "a", product.base_project.title)
      assert has_element?(view, "a", product_2.base_project.title)
    end

    @tag :flaky
    test "search product by amount", %{conn: conn, product: product} do
      [{_, product_2} | _] = create_product(conn)

      {:ok, product_2} =
        Sections.update_section(product_2, %{
          amount: Money.new(:USD, 25)
        })

      {:ok, view, _html} = live(conn, @live_view_all_products)

      assert has_element?(view, "a", product.title)
      assert has_element?(view, "a", product_2.title)

      render_hook(view, "text_search_change", %{value: "25"})

      wait_while(fn -> has_element?(view, "a", product.title) end)

      refute has_element?(view, "a", product.title)
      assert has_element?(view, "a", product_2.title)

      view
      |> element("button[phx-click=\"text_search_reset\"]")
      |> render_click()

      assert has_element?(view, "a", product.title)
      assert has_element?(view, "a", product_2.title)
    end

    test "applies sorting by creation date", %{conn: conn, product: product} do
      product_2 =
        insert(:section,
          type: :blueprint,
          requires_payment: true,
          amount: Money.new(:USD, 10),
          inserted_at: yesterday(product.inserted_at)
        )

      {:ok, view, _html} = live(conn, @live_view_all_products)

      view
      |> element("th[phx-click=\"paged_table_sort\"][phx-value-sort_by=\"inserted_at\"]")
      |> render_click()

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~ product_2.title

      assert view
             |> element("tr:last-child > td:first-child")
             |> render() =~ product.title

      view
      |> element("th[phx-click=\"paged_table_sort\"][phx-value-sort_by=\"inserted_at\"]")
      |> render_click()

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~ product.title

      assert view
             |> element("tr:last-child > td:first-child")
             |> render() =~ product_2.title
    end

    test "include archived products", %{conn: conn, product: product} do
      product_2 =
        insert(:section,
          type: :blueprint,
          requires_payment: true,
          amount: Money.new(:USD, 10),
          inserted_at: yesterday(),
          status: :archived
        )

      {:ok, view, _html} = live(conn, @live_view_all_products)

      assert has_element?(view, "a", product.base_project.title)
      refute has_element?(view, "a", product_2.base_project.title)

      view
      |> element("input[phx-click=\"include_archived\"]")
      |> render_click()

      assert has_element?(view, "a", product.base_project.title)
      assert has_element?(view, "a", product_2.base_project.title)
    end

    test "applies paging", %{conn: conn} do
      [first_p | tail] = insert_list(21, :section) |> Enum.sort_by(& &1.title)
      last_p = List.last(tail)

      {:ok, view, _html} = live(conn, @live_view_all_products)

      assert has_element?(view, "##{first_p.id}")
      refute has_element?(view, "##{last_p.id}")

      view
      |> element("#header_paging button[phx-click=\"paged_table_page_change\"]", "2")
      |> render_click()

      refute has_element?(view, "##{first_p.id}")
      assert has_element?(view, "##{last_p.id}")
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
        "/authors/log_in"

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

      path = "assets/static/images/course_default.png"

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

      path = "assets/static/images/course_default.png"

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

  describe "user cannot create product until after project is published" do
    setup [:author_conn]

    test "redirects to new session when accessing the section overview view", %{
      conn: conn,
      author: author
    } do
      seeds =
        Seeder.Project.create_sample_project(%{}, author,
          project_tag: :project,
          publication_tag: :publication
        )

      %{project: project, publication: publication} = seeds

      {:ok, view, _html} = live(conn, live_view_products_route(project.slug))

      assert render(view) =~ "Products cannot be created until project is published"

      Seeder.Project.ensure_published(seeds, publication)

      {:ok, view, _html} = live(conn, live_view_products_route(project.slug))

      assert render(view) =~ "Create a new product with title"
    end
  end

  describe "product overview - transfer payment codes" do
    setup [:admin_conn, :create_product_with_payment_codes]

    test "shows transfer payment codes button if product has payment codes and project has this option enabled",
         %{conn: conn, product: product} do
      allow_transfer_payment_codes(product.base_project)

      {:ok, view, _html} = live(conn, ~p"/authoring/products/#{product.slug}")

      assert view
             |> element("button[phx-click=\"show_products_to_transfer\"]")
             |> render() =~ "Transfer Payment Codes"

      assert has_element?(view, "div", "Allow transfer of payment codes to another product.")
    end

    test "does not show transfer payment codes button if project has this option disabled", %{
      conn: conn,
      product: product
    } do
      {:ok, view, _html} = live(conn, ~p"/authoring/products/#{product.slug}")

      refute has_element?(view, "button", "Transfer Payment Codes")

      refute has_element?(view, "div", "Allow transfer of payment codes to another product.")
    end

    test "does not show transfer payment codes button if product has no payment codes", %{
      conn: conn
    } do
      product =
        insert(:section, type: :blueprint, requires_payment: true, amount: Money.new(:USD, 10))

      allow_transfer_payment_codes(product.base_project)

      {:ok, view, _html} = live(conn, ~p"/authoring/products/#{product.slug}")

      refute has_element?(view, "button", "Transfer Payment Codes")

      refute has_element?(view, "div", "Allow transfer of payment codes to another product.")
    end

    test "shows a modal to select another product to transfer payment codes when clicking on transfer payment codes button",
         %{conn: conn, product: product} do
      product_2 =
        insert(:section,
          type: :blueprint,
          requires_payment: true,
          amount: Money.new(:USD, 10),
          base_project: product.base_project,
          base_project_id: product.base_project_id
        )

      allow_transfer_payment_codes(product.base_project)

      {:ok, view, _html} = live(conn, ~p"/authoring/products/#{product.slug}")

      view
      |> element("button[phx-click=\"show_products_to_transfer\"]")
      |> render_click()

      assert has_element?(view, "h5", "Transfer Payment Codes")

      assert has_element?(
               view,
               "h6",
               "Select a product to transfer payment codes from this product."
             )

      assert has_element?(view, ".torus-select option", product_2.title)
    end

    test "shows a message when there are no products available to transfer payment codes", %{
      conn: conn,
      product: product
    } do
      allow_transfer_payment_codes(product.base_project)

      {:ok, view, _html} = live(conn, ~p"/authoring/products/#{product.slug}")

      view
      |> element("button[phx-click=\"show_products_to_transfer\"]")
      |> render_click()

      assert has_element?(
               view,
               "h6",
               "There are no products available to transfer payment codes."
             )
    end

    test "transfers payment codes to another product", %{conn: conn, product: product} do
      product_2 =
        insert(:section,
          type: :blueprint,
          requires_payment: true,
          amount: Money.new(:USD, 10),
          base_project: product.base_project,
          base_project_id: product.base_project_id
        )

      allow_transfer_payment_codes(product.base_project)

      {:ok, view, _html} = live(conn, ~p"/authoring/products/#{product.slug}")

      view
      |> element("button[phx-click=\"show_products_to_transfer\"]")
      |> render_click()

      view
      |> element("form[phx-submit=\"submit_transfer_payment_codes\"]")
      |> render_submit(%{
        "product_id" => product_2.id
      })

      refute Paywall.has_payment_codes?(product.id)
      assert Paywall.has_payment_codes?(product_2.id)

      flash =
        assert_redirected(
          view,
          ~p"/authoring/products/#{product.slug}"
        )

      assert flash["info"] == "Payment codes transferred successfully"
    end
  end

  defp allow_transfer_payment_codes(project) do
    Course.update_project(project, %{
      allow_transfer_payment_codes: true
    })
  end
end
