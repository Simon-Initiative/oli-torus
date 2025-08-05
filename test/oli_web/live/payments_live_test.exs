defmodule OliWeb.PaymentsLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Delivery.Paywall
  alias Oli.Delivery.Paywall.Payment

  defp create_product(_conn) do
    product =
      insert(:section, type: :blueprint, requires_payment: true, amount: Money.new(10, "USD"))

    [product: product]
  end

  defp create_payment_code(product) do
    user = insert(:user)
    insert(:enrollment, section: product, user: user)

    {:ok, [payment | _]} = Paywall.create_payment_codes(product.slug, 1)
    code_to_test = Payment.to_human_readable(payment.code)

    Paywall.redeem_code(code_to_test, user, product.slug)
    {user, product, payment}
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
        "/authors/log_in"

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
      redirect_path = "/workspaces/course_author"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_product_route(product_slug))
    end
  end

  describe "payments" do
    setup [:admin_conn, :create_product, :stub_real_current_time]

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
      |> render_blur(%{value: "1"})

      # Simulate clicking on the button to create payment codes
      view
      |> element("button[phx-click=\"create\"]")
      |> render_click()

      # Get the payment codes generated for a current product
      [hd | _] = codes = Paywall.list_payments_by_count(product.slug, 1)
      code_to_test = Payment.to_human_readable(hd.code)

      # Test that payment codes were obtained.
      assert length(codes) == 1

      # Test that the table contains at least one code
      assert view
             |> element("tr:first-child > td:first-child > div")
             |> render() =~ "Code: <code>#{code_to_test}</code>"
    end

    test "section title is a link to the instructor dashboard", %{conn: conn, product: product} do
      {user, product, _} = create_payment_code(product)

      {:ok, view, _html} = live(conn, live_view_payments_route(product.slug))

      assert has_element?(
               view,
               "a[href=\"/sections/#{product.slug}/instructor_dashboard/overview\"]",
               "#{product.title}"
             )

      assert has_element?(
               view,
               "a[href=\"/sections/#{product.slug}/student_dashboard/#{user.id}/content\"]",
               "#{user.family_name}, #{user.given_name}"
             )
    end

    test "The username is a link to the student details view for that student in that section",
         %{conn: conn, product: product} do
      {user, product, _} = create_payment_code(product)

      {:ok, view, _html} = live(conn, live_view_payments_route(product.slug))

      assert has_element?(
               view,
               "a[href=\"/sections/#{product.slug}/instructor_dashboard/overview\"]",
               "#{product.title}"
             )

      assert has_element?(
               view,
               "a[href=\"/sections/#{product.slug}/student_dashboard/#{user.id}/content\"]",
               "#{user.family_name}, #{user.given_name}"
             )
    end

    test "search payment by code", %{conn: conn, product: product} do
      {_, product, payment1} = create_payment_code(product)
      {_, product, payment2} = create_payment_code(product)

      {:ok, view, _html} = live(conn, live_view_payments_route(product.slug))

      code1 = Paywall.Payment.to_human_readable(payment1.code)
      code2 = Paywall.Payment.to_human_readable(payment2.code)

      assert has_element?(view, "div", code1)
      assert has_element?(view, "div", code2)

      render_hook(view, "text_search_change", %{value: code1})

      assert has_element?(view, "div", code1)
      refute has_element?(view, "div", code2)

      view
      |> element("button[phx-click=\"text_search_reset\"]")
      |> render_click()

      assert has_element?(view, "div", code1)
      assert has_element?(view, "div", code2)
    end

    test "search payment by section title", %{conn: conn, product: product} do
      {_, _product, _payment1} = create_payment_code(product)
      {_, _product, _payment2} = create_payment_code(product)

      {:ok, view, _html} = live(conn, live_view_payments_route(product.slug))

      assert has_element?(view, "div", product.title)
      assert has_element?(view, "div", product.title)

      render_hook(view, "text_search_change", %{value: product.title})

      assert has_element?(view, "div", product.title)
      assert has_element?(view, "div", product.title)
    end

    test "applies sorting", %{conn: conn, product: product} do
      {_, _product, payment1} = create_payment_code(product)
      {_, _product, payment2} = create_payment_code(product)

      {:ok, view, _html} = live(conn, live_view_payments_route(product.slug))

      code1 = Paywall.Payment.to_human_readable(payment1.code)
      code2 = Paywall.Payment.to_human_readable(payment2.code)

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               code1

      view
      |> element("th[phx-click=\"paged_table_sort\"]:first-of-type")
      |> render_click(%{sort_by: "user"})

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               code2
    end
  end
end
