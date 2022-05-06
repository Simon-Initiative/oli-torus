defmodule OliWeb.DiscountsLiveTest do
  use ExUnit.Case
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Delivery.Paywall
  alias Oli.Delivery.Paywall.Discount

  defp live_view_route(type, entity_slug) do
    Routes.discount_path(OliWeb.Endpoint, type, entity_slug)
  end

  describe "user cannot access when is not logged in" do
    test "redirects to new session when accessing the view - product", %{conn: conn} do
      product = insert(:section, type: :blueprint, lti_1p3_deployment: insert(:lti_deployment))

      redirect_path =
        "/authoring/session/new?request_path=%2Fadmin%2Fproducts%2F#{product.slug}%2Fdiscounts"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_route(:product, product.slug))
    end

    test "redirects to new session when accessing the view - institution", %{conn: conn} do
      institution = insert(:institution)

      redirect_path =
        "/authoring/session/new?request_path=%2Fadmin%2Finstitutions%2F#{institution.id}%2Fdiscounts"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_route(:institution, institution.id))
    end
  end

  describe "user cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn]

    test "returns forbidden when accessing the view - product", %{conn: conn} do
      product = insert(:section, type: :blueprint, lti_1p3_deployment: insert(:lti_deployment))

      conn = get(conn, live_view_route(:product, product.slug))

      assert response(conn, 403)
    end

    test "returns forbidden when accessing the view - institution", %{conn: conn} do
      institution = insert(:institution)

      conn = get(conn, live_view_route(:institution, institution.id))

      assert response(conn, 403)
    end
  end

  describe "discount view" do
    setup [:admin_conn]

    test "redirects to not found when not exists - product", %{conn: conn} do
      # section without lti deployment
      product = insert(:section, type: :blueprint)

      {:error, {:redirect, %{to: "/not_found"}}} = live(conn, live_view_route(:product, product.slug))
    end

    test "redirects to not found when not exists - institution", %{conn: conn} do
      {:error, {:redirect, %{to: "/not_found"}}} = live(conn, live_view_route(:institution, 123))
    end

    test "loads correctly with no discount - product", %{conn: conn} do
      deployment = insert(:lti_deployment)
      product = insert(:section, type: :blueprint, lti_1p3_deployment: deployment)

      {:ok, view, _html} = live(conn, live_view_route(:product, product.slug))

      assert has_element?(view, "h5", "Manage Discount")
      assert has_element?(view, "form[phx-submit=\"save\"")
      assert has_element?(view, "input[value=\"#{deployment.institution.name}\"")
    end

    test "loads correctly with no discount - institution", %{conn: conn} do
      institution = insert(:institution)

      {:ok, view, _html} = live(conn, live_view_route(:institution, institution.id))

      assert has_element?(view, "h5", "Manage Discount")
      assert has_element?(view, "form[phx-submit=\"save\"")
      assert has_element?(view, "input[value=\"#{institution.name}\"")
    end

    test "loads correctly with discount - product", %{conn: conn} do
      deployment = insert(:lti_deployment)
      product = insert(:section, type: :blueprint, lti_1p3_deployment: deployment)
      discount = insert(:discount, section: product, institution: deployment.institution)

      {:ok, view, _html} = live(conn, live_view_route(:product, product.slug))

      assert has_element?(view, "h5", "Manage Discount")
      assert has_element?(view, "form[phx-submit=\"save\"")
      assert has_element?(view, "input[value=\"#{deployment.institution.name}\"")
      assert has_element?(view, "input[value=\"#{discount.amount}\"")
      assert has_element?(view, "input[value=\"#{discount.percentage}\"")
    end

    test "loads correctly with discount - institution", %{conn: conn} do
      institution = insert(:institution)
      discount = insert(:discount, section: nil, institution: institution)

      {:ok, view, _html} = live(conn, live_view_route(:institution, institution.id))

      assert has_element?(view, "h5", "Manage Discount")
      assert has_element?(view, "form[phx-submit=\"save\"")
      assert has_element?(view, "input[value=\"#{institution.name}\"")
      assert has_element?(view, "input[value=\"#{discount.amount}\"")
      assert has_element?(view, "input[value=\"#{discount.percentage}\"")
    end

    test "displays error message when data is invalid - product", %{conn: conn} do
      deployment = insert(:lti_deployment)
      product = insert(:section, type: :blueprint, lti_1p3_deployment: deployment)

      {:ok, view, _html} = live(conn, live_view_route(:product, product.slug))

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{discount: %{type: "fixed_amount"}})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Discount couldn&#39;t be created/updated. Please check the errors below."
      assert has_element?(view, "span", "can't be blank")
      refute Paywall.get_discount_by!(%{
        section_id: product.id,
        institution_id: deployment.institution.id
      })
    end

    test "displays error message when data is invalid - institution", %{conn: conn} do
      institution = insert(:institution)

      {:ok, view, _html} = live(conn, live_view_route(:institution, institution.id))

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{discount: %{type: "fixed_amount"}})

      assert view
            |> element("div.alert.alert-danger")
            |> render() =~
              "Discount couldn&#39;t be created/updated. Please check the errors below."
      assert has_element?(view, "span", "can't be blank")
      refute Paywall.get_institution_wide_discount!(institution.id)
    end

    test "saves discount when data is valid - product", %{conn: conn} do
      deployment = insert(:lti_deployment)
      product = insert(:section, type: :blueprint, lti_1p3_deployment: deployment)
      params = params_for(:discount)

      {:ok, view, _html} = live(conn, live_view_route(:product, product.slug))

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{
        discount: params
      })

      assert view
            |> element("div.alert.alert-info")
            |> render() =~
              "Discount successfully created/updated."

      %Discount{type: type, percentage: percentage} = Paywall.get_discount_by!(%{
        section_id: product.id,
        institution_id: deployment.institution.id
      })

      assert type == params.type
      assert percentage == params.percentage
    end

    test "saves discount when data is valid - institution", %{conn: conn} do
      institution = insert(:institution)
      params = params_for(:discount)

      {:ok, view, _html} = live(conn, live_view_route(:institution, institution.id))

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{
        discount: params
      })

      assert view
            |> element("div.alert.alert-info")
            |> render() =~
              "Discount successfully created/updated."

      %Discount{type: type, percentage: percentage} =
        Paywall.get_institution_wide_discount!(institution.id)

      assert type == params.type
      assert percentage == params.percentage
    end

    test "clears discount correctly - product", %{conn: conn} do
      deployment = insert(:lti_deployment)
      product = insert(:section, type: :blueprint, lti_1p3_deployment: deployment)
      insert(:discount, section: product, institution: deployment.institution)

      {:ok, view, _html} = live(conn, live_view_route(:product, product.slug))

      view
      |> element("button[phx-click=\"clear\"")
      |> render_click()

      assert view
            |> element("div.alert.alert-info")
            |> render() =~
              "Discount successfully cleared."

      refute Paywall.get_discount_by!(%{
        section_id: product.id,
        institution_id: deployment.institution.id
      })
    end

    test "clears discount correctly - institution", %{conn: conn} do
      institution = insert(:institution)
      insert(:discount, section: nil, institution: institution)

      {:ok, view, _html} = live(conn, live_view_route(:institution, institution.id))

      view
      |> element("button[phx-click=\"clear\"")
      |> render_click()

      assert view
            |> element("div.alert.alert-info")
            |> render() =~
              "Discount successfully cleared."

      refute Paywall.get_institution_wide_discount!(institution.id)
    end
  end
end
