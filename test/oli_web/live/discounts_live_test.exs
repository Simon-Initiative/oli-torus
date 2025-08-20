defmodule OliWeb.DiscountsLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Delivery.Paywall
  alias Oli.Delivery.Paywall.Discount

  defp live_view_products_index_route(product_slug),
    do:
      Routes.live_path(
        OliWeb.Endpoint,
        OliWeb.Products.Payments.Discounts.ProductsIndexView,
        product_slug
      )

  defp live_view_product_show_route(product_slug, discount_id),
    do: Routes.discount_path(OliWeb.Endpoint, :product, product_slug, discount_id)

  defp live_view_product_new_show_route(product_slug),
    do: Routes.discount_path(OliWeb.Endpoint, :product_new, product_slug)

  defp live_view_institution_show_route(institution_id),
    do: Routes.discount_path(OliWeb.Endpoint, :institution, institution_id)

  defp create_product(_conn) do
    product = insert(:section, type: :blueprint)

    [product: product]
  end

  describe "user cannot access when is not logged in" do
    test "redirects to new session when accessing the products index view", %{conn: conn} do
      product = insert(:section, type: :blueprint)

      redirect_path =
        "/authors/log_in"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_products_index_route(product.slug))
    end

    test "redirects to new session when accessing the new show view - product", %{conn: conn} do
      product = insert(:section, type: :blueprint)

      redirect_path =
        "/authors/log_in"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_product_new_show_route(product.slug))
    end

    test "redirects to new session when accessing the show view - product", %{conn: conn} do
      product = insert(:section, type: :blueprint)
      discount = insert(:discount, section: product)

      redirect_path =
        "/authors/log_in"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_product_show_route(product.slug, discount.id))
    end

    test "redirects to new session when accessing the show view - institution", %{conn: conn} do
      institution = insert(:institution)

      redirect_path =
        "/authors/log_in"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_institution_show_route(institution.id))
    end
  end

  describe "user cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn]

    test "returns forbidden when accessing the products index view", %{conn: conn} do
      product = insert(:section, type: :blueprint)

      conn = get(conn, live_view_products_index_route(product.slug))

      assert redirected_to(conn) =~ "/workspaces/course_author"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You are not authorized to access this page."
    end

    test "returns forbidden when accessing the new show view - product", %{conn: conn} do
      product = insert(:section, type: :blueprint)

      conn = get(conn, live_view_product_new_show_route(product.slug))

      assert redirected_to(conn) =~ "/workspaces/course_author"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You are not authorized to access this page."
    end

    test "returns forbidden when accessing the show view - product", %{conn: conn} do
      product = insert(:section, type: :blueprint)
      discount = insert(:discount, section: product)

      conn = get(conn, live_view_product_show_route(product.slug, discount.id))

      assert redirected_to(conn) =~ "/workspaces/course_author"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You are not authorized to access this page."
    end

    test "returns forbidden when accessing the show view - institution", %{conn: conn} do
      institution = insert(:institution)

      conn = get(conn, live_view_institution_show_route(institution.id))

      assert redirected_to(conn) =~ "/workspaces/course_author"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You are not authorized to access this page."
    end
  end

  describe "products discounts index view" do
    setup [:admin_conn, :create_product]

    test "loads correctly when there are no discounts", %{conn: conn, product: product} do
      {:ok, view, _html} = live(conn, live_view_products_index_route(product.slug))

      assert has_element?(view, "#discounts-table")
      assert has_element?(view, "p", "None exist")
      assert has_element?(view, "a[href=\"#{live_view_product_new_show_route(product.slug)}\"]")
    end

    test "loads correctly when there are discounts", %{conn: conn, product: product} do
      first_discount =
        insert(:discount, section: product, type: :fixed_amount, amount: Money.new(25, "USD"))

      second_discount = insert(:discount, section: product, percentage: 20)

      {:ok, view, _html} = live(conn, live_view_products_index_route(product.slug))

      assert has_element?(view, "#discounts-table")

      assert view
             |> element("tbody tr[id='#{first_discount.id}']")
             |> render() =~ "Fixed price"

      assert view
             |> element("tbody tr[id='#{second_discount.id}']")
             |> render() =~ "Percentage"
    end

    test "applies sorting", %{conn: conn, product: product} do
      first_discount = insert(:discount, section: product)
      second_discount = insert(:discount, section: product, percentage: 20)

      {:ok, view, _html} = live(conn, live_view_products_index_route(product.slug))

      view
      |> element("th[phx-click='sort']:first-of-type")
      |> render_click(%{sort_by: "value"})

      assert has_element?(view, "tbody tr:first-child[id='#{first_discount.id}']")

      view
      |> element("th[phx-click='sort']:first-of-type")
      |> render_click(%{sort_by: "value"})

      assert has_element?(view, "tbody tr:first-child[id='#{second_discount.id}']")
    end

    test "applies paging", %{conn: conn, product: product} do
      first_discount =
        insert(:discount,
          section: product,
          inserted_at: DateTime.utc_now() |> DateTime.add(-3600, :second)
        )

      [_head | tail] =
        insert_list(21, :discount, section: product) |> Enum.sort_by(& &1.inserted_at)

      last_discount = List.last(tail)

      {:ok, view, _html} = live(conn, live_view_products_index_route(product.slug))

      view
      |> element("th[phx-click='sort']:first-of-type")
      |> render_click(%{sort_by: "inserted_at"})

      assert has_element?(view, "##{first_discount.id}")
      refute has_element?(view, "##{last_discount.id}")

      view
      |> element("button[phx-click='page_change']", "2")
      |> render_click()

      refute has_element?(view, "##{first_discount.id}")
      assert has_element?(view, "##{last_discount.id}")
    end

    test "renders datetimes using the local timezone", %{product: product} = context do
      {:ok, conn: conn, ctx: session_context} = set_timezone(context)

      discount = insert(:discount, section: product)

      {:ok, view, _html} = live(conn, live_view_products_index_route(product.slug))

      assert view
             |> element("tbody tr:first-child[id='#{discount.id}']")
             |> render() =~
               OliWeb.Common.Utils.render_date(discount, :inserted_at, session_context)
    end
  end

  describe "discount show view - product" do
    setup [:admin_conn, :create_product]

    test "redirects to not found when not exists", %{conn: conn} do
      product = insert(:section, type: :enrollable)
      discount = insert(:discount)

      {:error, {:redirect, %{to: "/not_found"}}} =
        live(conn, live_view_product_show_route(product.slug, discount.id))
    end

    test "loads correctly", %{conn: conn, product: product} do
      discount = insert(:discount, section: product)

      {:ok, view, _html} = live(conn, live_view_product_show_route(product.slug, discount.id))

      assert has_element?(view, "h5", "Manage Discount")
      assert has_element?(view, "option", "Fixed price")
      assert has_element?(view, "option", "Percentage")
      assert has_element?(view, "label", "Price")
      assert has_element?(view, "label", "Percentage")
      assert has_element?(view, "form[phx-submit='save']")
      assert has_element?(view, "input[value='#{discount.institution.name}']")
      # type is percentage
      assert has_element?(view, "input[name='discount[amount]'][disabled]")
      assert has_element?(view, "input[value='#{discount.percentage}']")
    end

    test "displays error message when data is invalid", %{conn: conn, product: product} do
      discount = insert(:discount, section: product)

      {:ok, view, _html} = live(conn, live_view_product_show_route(product.slug, discount.id))

      view
      |> element("form[phx-submit='save']")
      |> render_submit(%{discount: %{type: "fixed_amount"}})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Discount couldn&#39;t be created/updated. Please check the errors below."

      assert has_element?(view, "p", "can't be blank")

      refute %Discount{type: :fixed_amount} ==
               Paywall.get_discount_by!(%{
                 section_id: product.id,
                 institution_id: discount.institution.id
               })
    end

    test "saves discount when data is valid", %{conn: conn, product: product} do
      discount = insert(:discount, section: product)
      params = params_for(:discount)

      {:ok, view, _html} = live(conn, live_view_product_show_route(product.slug, discount.id))

      view
      |> element("form[phx-submit='save']")
      |> render_submit(%{
        discount: params
      })

      flash = assert_redirected(view, live_view_products_index_route(product.slug))
      assert flash["info"] == "Discount successfully created/updated."

      %Discount{type: type, percentage: percentage} =
        Paywall.get_discount_by!(%{
          section_id: product.id,
          institution_id: discount.institution.id
        })

      assert type == params.type
      assert percentage == params.percentage
    end
  end

  describe "discount show view - new product" do
    setup [:admin_conn, :create_product]

    test "redirects to not found when not exists", %{conn: conn} do
      product = insert(:section, type: :enrollable)

      {:error, {:redirect, %{to: "/not_found"}}} =
        live(conn, live_view_product_new_show_route(product.slug))
    end

    test "loads correctly", %{conn: conn, product: product} do
      institution = insert(:institution)

      {:ok, view, _html} = live(conn, live_view_product_new_show_route(product.slug))

      assert has_element?(view, "h5", "New Discount")
      assert has_element?(view, "option", "Fixed price")
      assert has_element?(view, "option", "Percentage")
      assert has_element?(view, "label", "Price")
      assert has_element?(view, "label", "Percentage")
      assert has_element?(view, "form[phx-submit='save']")
      assert has_element?(view, "option[value='#{institution.id}']", "#{institution.name}")
      refute has_element?(view, "button[phx-click='clear']")
    end

    test "displays error message when data is invalid", %{conn: conn, product: product} do
      {:ok, view, _html} = live(conn, live_view_product_new_show_route(product.slug))

      view
      |> element("form[phx-submit='save']")
      |> render_submit(%{discount: %{type: "fixed_amount"}})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Discount couldn&#39;t be created/updated. Please check the errors below."

      assert [] = Paywall.get_product_discounts(product.id)
    end

    test "saves discount when data is valid", %{conn: conn, product: product} do
      params = params_with_assocs(:discount)

      {:ok, view, _html} = live(conn, live_view_product_new_show_route(product.slug))

      view
      |> element("form[phx-submit='save']")
      |> render_submit(%{
        discount: params
      })

      flash = assert_redirected(view, live_view_products_index_route(product.slug))
      assert flash["info"] == "Discount successfully created/updated."

      [%Discount{type: type, percentage: percentage}] = Paywall.get_product_discounts(product.id)
      assert type == params.type
      assert percentage == params.percentage
    end
  end

  describe "discount show view - institution" do
    setup [:admin_conn]

    test "redirects to not found when not exists", %{conn: conn} do
      {:error, {:redirect, %{to: "/not_found"}}} =
        live(conn, live_view_institution_show_route(000_123))
    end

    test "loads correctly with no discount", %{conn: conn} do
      institution = insert(:institution)

      {:ok, view, _html} = live(conn, live_view_institution_show_route(institution.id))

      assert has_element?(view, "h5", "Manage Discount")
      assert has_element?(view, "option", "Fixed price")
      assert has_element?(view, "option", "Percentage")
      assert has_element?(view, "label", "Price")
      assert has_element?(view, "label", "Percentage")
      assert has_element?(view, "form[phx-submit='save']")
      assert has_element?(view, "input[value='#{institution.name}']")
    end

    test "loads correctly with discount", %{conn: conn} do
      institution = insert(:institution)

      discount =
        insert(:discount,
          type: :fixed_amount,
          amount: Money.new(25, "USD"),
          percentage: nil,
          section: nil,
          institution: institution
        )

      {:ok, view, _html} = live(conn, live_view_institution_show_route(institution.id))

      assert has_element?(view, "h5", "Manage Discount")
      assert has_element?(view, "option", "Fixed price")
      assert has_element?(view, "option", "Percentage")
      assert has_element?(view, "label", "Price")
      assert has_element?(view, "label", "Percentage")
      assert has_element?(view, "form[phx-submit='save']")
      assert has_element?(view, "input[value='#{institution.name}']")
      assert has_element?(view, "input[value='#{discount.amount}']")
      # type is fixed_amount
      assert has_element?(view, "input[name='discount[percentage]'][disabled]")
    end

    test "displays error message when data is invalid", %{conn: conn} do
      institution = insert(:institution)

      {:ok, view, _html} = live(conn, live_view_institution_show_route(institution.id))

      view
      |> element("form[phx-submit='save']")
      |> render_submit(%{discount: %{type: "fixed_amount"}})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Discount couldn&#39;t be created/updated. Please check the errors below."

      assert has_element?(view, "p", "can't be blank")
      refute Paywall.get_institution_wide_discount!(institution.id)
    end

    test "saves discount when data is valid", %{conn: conn} do
      institution = insert(:institution)
      params = params_for(:discount)

      {:ok, view, _html} = live(conn, live_view_institution_show_route(institution.id))

      view
      |> element("form[phx-submit='save']")
      |> render_submit(%{
        discount: params
      })

      flash =
        assert_redirected(view, Routes.institution_path(OliWeb.Endpoint, :show, institution.id))

      assert flash["info"] == "Discount successfully created/updated."

      %Discount{type: type, percentage: percentage} =
        Paywall.get_institution_wide_discount!(institution.id)

      assert type == params.type
      assert percentage == params.percentage
    end

    test "clears discount correctly - institution", %{conn: conn} do
      institution = insert(:institution)
      insert(:discount, section: nil, institution: institution)

      {:ok, view, _html} = live(conn, live_view_institution_show_route(institution.id))

      view
      |> element("button[phx-click='clear']")
      |> render_click()

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Discount successfully cleared."

      refute Paywall.get_institution_wide_discount!(institution.id)
    end
  end
end
