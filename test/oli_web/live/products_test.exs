defmodule OliWeb.ProductsLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory
  import Mox
  import Floki

  alias Oli.Delivery.{Paywall, Sections}
  alias Oli.Utils.Seeder
  alias Oli.Authoring.Course

  defp live_view_products_route(project_slug) do
    ~p"/workspaces/course_author/#{project_slug}/products"
  end

  defp admin_products_route do
    ~p"/admin/products"
  end

  defp project_slug_for(product) do
    case product.base_project do
      %{slug: slug} -> slug
      _ -> Course.get_project!(product.base_project_id).slug
    end
  end

  defp live_view_details_route(product) do
    project_slug = project_slug_for(product)
    ~p"/workspaces/course_author/#{project_slug}/products/#{product.slug}"
  end

  defp create_product(_conn) do
    product =
      insert(:section, type: :blueprint, requires_payment: true, amount: Money.new(10, "USD"))

    [product: product]
  end

  defp create_product_with_payment_codes(_conn) do
    product =
      insert(:section, type: :blueprint, requires_payment: true, amount: Money.new(10, "USD"))

    stub_real_current_time()
    Paywall.create_payment_codes(product.slug, 20)

    [product: product]
  end

  defp create_product_in_project(product, attrs \\ []) do
    default_attrs = %{
      type: :blueprint,
      requires_payment: true,
      amount: Money.new(10, "USD"),
      base_project: product.base_project,
      base_project_id: product.base_project_id
    }

    attrs = Enum.into(attrs, %{})

    insert(:section, Map.merge(default_attrs, attrs))
  end

  describe "product overview content settings" do
    setup [:admin_conn, :create_product]

    test "save event updates curriculum numbering visibility", %{conn: conn, product: product} do
      {:ok, view, _html} = live(conn, live_view_details_route(product))

      assert view
             |> element("#section_display_curriculum_item_numbering")
             |> render() =~ "checked"

      view
      |> element("#content-form form[phx-change='save']")
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
      {:ok, view, _html} = live(conn, live_view_details_route(product))

      refute view
             |> element("#section_apply_major_updates")
             |> render() =~ "checked"

      view
      |> element("#content-form form[phx-change='save']")
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
      product_2 = create_product_in_project(product)

      {:ok, view, _html} =
        live(conn, admin_products_route())

      assert has_element?(view, "a", product.title)
      assert has_element?(view, "a", product_2.title)
    end

    test "search product by title", %{conn: conn, product: product} do
      product_2 = create_product_in_project(product)

      {:ok, view, _html} =
        live(conn, admin_products_route())

      assert has_element?(view, "a", product.title)
      assert has_element?(view, "a", product_2.title)

      view
      |> element("form[phx-change=\"text_search_change\"]")
      |> render_change(%{product_name: product.title})

      assert has_element?(view, "a", product.title)
      refute has_element?(view, "a", product_2.title)

      view
      |> element("form[phx-change='text_search_change']")
      |> render_change(%{product_name: ""})

      assert has_element?(view, "a", product.title)
      assert has_element?(view, "a", product_2.title)
    end

    test "search product by base project title", %{conn: conn, product: product} do
      product_2 = create_product_in_project(product)

      {:ok, view, _html} = live(conn, admin_products_route())

      assert has_element?(view, "a", product.title)
      assert has_element?(view, "a", product_2.title)

      view
      |> element("form[phx-change=\"text_search_change\"]")
      |> render_change(%{product_name: product_2.base_project.title})

      assert has_element?(view, "a", product.title)

      highlight_elements =
        render(view)
        |> parse_document!()
        |> find("span.search-highlight")
        |> Enum.map(&text/1)

      product.base_project.title
      |> String.split(~r/\s+/, trim: true)
      |> Enum.each(fn word ->
        assert Enum.any?(highlight_elements, fn t ->
                 String.downcase(t) == String.downcase(word)
               end)
      end)

      view
      |> element("form[phx-change='text_search_change']")
      |> render_change(%{product_name: ""})

      assert has_element?(view, "a", product.title)
      assert has_element?(view, "a", product_2.base_project.title)
    end

    @tag :flaky
    test "search product by amount", %{conn: conn, product: product} do
      product_2 = create_product_in_project(product)

      {:ok, product_2} =
        Sections.update_section(product_2, %{
          amount: Money.new(250, "USD")
        })

      {:ok, view, _html} = live(conn, admin_products_route())

      assert has_element?(view, "a", product.title)
      assert has_element?(view, "a", product_2.title)

      view
      |> element("form[phx-change=\"text_search_change\"]")
      |> render_change(%{product_name: "250"})

      wait_while(fn -> has_element?(view, "a", product.title) end)

      refute has_element?(view, "a", product.title)
      assert has_element?(view, "a", product_2.title)

      view
      |> element("form[phx-change='text_search_change']")
      |> render_change(%{product_name: ""})

      assert has_element?(view, "a", product.title)
      assert has_element?(view, "a", product_2.title)
    end

    test "search enforces minimum characters and highlights matches", %{
      conn: conn,
      product: product
    } do
      other_product = create_product_in_project(product)

      {:ok, view, _html} = live(conn, admin_products_route())

      view
      |> element("form[phx-change=\"text_search_change\"]")
      |> render_change(%{product_name: "pr"})

      assert has_element?(view, "a", product.title)
      assert has_element?(view, "a", other_product.title)
      refute has_element?(view, "span.search-highlight")

      view
      |> element("form[phx-change=\"text_search_change\"]")
      |> render_change(%{product_name: other_product.slug})

      wait_while(fn -> has_element?(view, "a", product.title) end)

      assert has_element?(view, "a", other_product.title)
      assert has_element?(view, "span.search-highlight")

      view
      |> element("form[phx-change=\"text_search_change\"]")
      |> render_change(%{product_name: ""})

      assert has_element?(view, "a", product.title)
      assert has_element?(view, "a", other_product.title)
      refute has_element?(view, "span.search-highlight")
    end

    @tag :flaky
    @tag :skip
    test "applies sorting by creation date", %{conn: conn, product: product} do
      product_2 =
        insert(:section,
          type: :blueprint,
          requires_payment: true,
          amount: Money.new(10, "USD"),
          inserted_at: yesterday(product.inserted_at)
        )

      {:ok, view, _html} = live(conn, admin_products_route())

      view
      |> element("th[phx-click='paged_table_sort'][phx-value-sort_by='inserted_at']")
      |> render_click()

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~ product_2.title

      assert view
             |> element("tr:last-child > td:first-child")
             |> render() =~ product.title

      view
      |> element("th[phx-click='paged_table_sort'][phx-value-sort_by='inserted_at']")
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
        create_product_in_project(product,
          inserted_at: yesterday(),
          status: :archived
        )

      {:ok, view, _html} = live(conn, admin_products_route())

      assert has_element?(view, "a", product.base_project.title)
      refute has_element?(view, "a", product_2.title)

      view
      |> element("input[phx-click='include_archived']")
      |> render_click()

      assert has_element?(view, "a", product.base_project.title)
      assert has_element?(view, "a", product_2.base_project.title)
    end

    test "applies paging", %{conn: conn, product: product} do
      first_p =
        create_product_in_project(product,
          title: "First Product",
          inserted_at: yesterday()
        )

      last_p =
        create_product_in_project(product,
          title: "Last Product",
          inserted_at: tomorrow()
        )

      Enum.each(1..21, fn _ ->
        create_product_in_project(product, inserted_at: DateTime.now!("Etc/UTC"))
      end)

      {:ok, view, _html} = live(conn, admin_products_route())

      assert has_element?(view, "##{last_p.id}")
      refute has_element?(view, "##{first_p.id}")

      view
      |> element("#footer_paging button[phx-click='paged_table_page_change']", "2")
      |> render_click()

      refute has_element?(view, "##{last_p.id}")
      assert has_element?(view, "##{first_p.id}")
    end
  end

  describe "user cannot access when is not logged in" do
    setup [:create_product]

    test "redirects to new session when accessing the product detail view", %{
      conn: conn,
      product: product
    } do
      redirect_path =
        "/authors/log_in"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_details_route(product))
    end
  end

  describe "user cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn, :create_product]

    test "redirects to new session when accessing the section overview view", %{
      conn: conn,
      product: product
    } do
      conn = get(conn, live_view_details_route(product))

      redirect_path = "/workspaces/course_author"
      assert redirected_to(conn, 302) =~ redirect_path
    end
  end

  describe "details live view" do
    setup [:admin_conn, :create_product]

    test "returns 404 when product not exists", %{conn: conn, product: product} do
      project_slug = project_slug_for(product)
      conn = get(conn, ~p"/workspaces/course_author/#{project_slug}/products/not_exists")

      redirect_path = "/not_found"
      assert redirected_to(conn, 302) =~ redirect_path
    end

    test "loads product data correctly", %{conn: conn, product: product} do
      {:ok, view, _html} = live(conn, live_view_details_route(product))

      assert render(view) =~ "Details"
      assert render(view) =~ "The Product title and description"
      assert has_element?(view, "input[value=\"#{product.title}\"]")
      assert has_element?(view, "input[name=\"section[pay_by_institution]\"]")

      project_slug = project_slug_for(product)

      assert has_element?(
               view,
               "a[href=\"/workspaces/course_author/#{project_slug}/products/#{product.slug}/discounts\"]"
             )
    end
  end

  describe "product overview image upload" do
    setup [:admin_conn, :create_product]

    test "displays the current image", %{conn: conn} do
      product =
        insert(:section, type: :blueprint, cover_image: "https://example.com/some-image-url.png")

      {:ok, view, _html} = live(conn, live_view_details_route(product))

      assert view
             |> element("#img-preview img")
             |> render() =~ "src=\"https://example.com/some-image-url.png\""
    end

    test "submit button is disabled if no file has been uploaded", %{conn: conn, product: product} do
      {:ok, view, _html} = live(conn, live_view_details_route(product))

      assert view
             |> element("#img-upload-form button[type=\"submit\"]")
             |> render() =~ "disabled"
    end

    test "file is uploaded", %{conn: conn, product: product} do
      Oli.Test.MockAws
      |> expect(:request, 1, fn %ExAws.Operation.S3{} ->
        {:ok, %{status_code: 200}}
      end)

      {:ok, view, _html} = live(conn, live_view_details_route(product))

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

      {:ok, view, _html} = live(conn, live_view_details_route(product))

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
             |> has_element?("#img-upload-form div[role='progressbar']")

      view
      |> element("button[phx-click='cancel_upload']")
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

      {:ok, view, _html} = live(conn, live_view_details_route(product))

      assert view
             |> element("button[phx-click='show_products_to_transfer']")
             |> render() =~ "Transfer Payment Codes"

      assert has_element?(view, "div", "Allow transfer of payment codes to another product.")
    end

    test "does not show transfer payment codes button if project has this option disabled", %{
      conn: conn,
      product: product
    } do
      {:ok, view, _html} = live(conn, live_view_details_route(product))

      refute has_element?(view, "button", "Transfer Payment Codes")

      refute has_element?(view, "div", "Allow transfer of payment codes to another product.")
    end

    test "does not show transfer payment codes button if product has no payment codes", %{
      conn: conn
    } do
      product =
        insert(:section, type: :blueprint, requires_payment: true, amount: Money.new(10, "USD"))

      allow_transfer_payment_codes(product.base_project)

      {:ok, view, _html} = live(conn, live_view_details_route(product))

      refute has_element?(view, "button", "Transfer Payment Codes")

      refute has_element?(view, "div", "Allow transfer of payment codes to another product.")
    end

    test "shows a modal to select another product to transfer payment codes when clicking on transfer payment codes button",
         %{conn: conn, product: product} do
      product_2 =
        insert(:section,
          type: :blueprint,
          requires_payment: true,
          amount: Money.new(10, "USD"),
          base_project: product.base_project,
          base_project_id: product.base_project_id
        )

      allow_transfer_payment_codes(product.base_project)

      {:ok, view, _html} = live(conn, live_view_details_route(product))

      view
      |> element("button[phx-click='show_products_to_transfer']")
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

      {:ok, view, _html} = live(conn, live_view_details_route(product))

      view
      |> element("button[phx-click='show_products_to_transfer']")
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
          amount: Money.new(10, "USD"),
          base_project: product.base_project,
          base_project_id: product.base_project_id
        )

      allow_transfer_payment_codes(product.base_project)

      {:ok, view, _html} = live(conn, live_view_details_route(product))

      view
      |> element("button[phx-click='show_products_to_transfer']")
      |> render_click()

      view
      |> element("form[phx-submit='submit_transfer_payment_codes']")
      |> render_submit(%{
        "product_id" => product_2.id
      })

      refute Paywall.has_payment_codes?(product.id)
      assert Paywall.has_payment_codes?(product_2.id)

      flash =
        assert_redirected(
          view,
          live_view_details_route(product)
        )

      assert flash["info"] == "Payment codes transferred successfully"
    end
  end

  defp allow_transfer_payment_codes(project) do
    Course.update_project(project, %{
      allow_transfer_payment_codes: true
    })
  end

  describe "products with tags" do
    setup [:admin_conn, :create_product]

    test "displays product tags in table", %{conn: conn, product: product} do
      # Create and associate tags with the product
      {:ok, biology_tag} = Oli.Tags.create_tag(%{name: "Biology"})
      {:ok, chemistry_tag} = Oli.Tags.create_tag(%{name: "Chemistry"})
      {:ok, _} = Oli.Tags.associate_tag_with_section(product, biology_tag)
      {:ok, _} = Oli.Tags.associate_tag_with_section(product, chemistry_tag)

      {:ok, view, _html} = live(conn, admin_products_route())

      html = render(view)

      product_row =
        html
        |> parse_document!()
        |> find("tr")
        |> Enum.find(fn row -> text(row) =~ product.title end)

      assert product_row

      tag_elements = find(product_row, "[role='selected tag']")

      assert Enum.any?(tag_elements, fn el -> text(el) =~ "Biology" end)
      assert Enum.any?(tag_elements, fn el -> text(el) =~ "Chemistry" end)
    end

    test "displays empty tags column when product has no tags", %{conn: conn, product: product} do
      {:ok, view, _html} = live(conn, admin_products_route())

      html = render(view)

      product_row =
        html
        |> parse_document!()
        |> find("tr")
        |> Enum.find(fn row -> text(row) =~ product.title end)

      assert product_row
      assert find(product_row, "[role='selected tag']") == []
    end

    test "tags component is rendered in table cell", %{conn: conn, product: _product} do
      {:ok, view, _html} = live(conn, admin_products_route())

      # Check that the TagsComponent is rendered
      assert has_element?(view, "div[phx-hook='TagsComponent']")
    end

    test "tags work specifically with blueprint sections (products)", %{
      conn: conn,
      product: product
    } do
      # Ensure this is a blueprint section
      assert product.type == :blueprint

      {:ok, product_tag} = Oli.Tags.create_tag(%{name: "ProductTag"})
      {:ok, _} = Oli.Tags.associate_tag_with_section(product, product_tag)

      {:ok, view, _html} = live(conn, admin_products_route())

      # Should display the tag
      product_row = view |> element("##{product.id}") |> render()
      assert product_row =~ "ProductTag"
    end
  end
end
