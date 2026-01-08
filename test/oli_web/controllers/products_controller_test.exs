defmodule OliWeb.ProductsControllerTest do
  use OliWeb.ConnCase

  import Oli.Factory

  alias Oli.Accounts.SystemRole

  setup %{conn: conn} do
    admin =
      insert(:author, %{
        system_role_id: SystemRole.role_id().system_admin
      })

    product =
      insert(:section, %{
        type: :blueprint,
        title: "Alpha Product",
        slug: "alpha-product",
        requires_payment: true,
        amount: Money.new(15, "USD")
      })

    other_product =
      insert(:section, %{
        type: :blueprint,
        title: "Beta Product",
        slug: "beta-product",
        requires_payment: false
      })

    archived_product =
      insert(:section, %{
        type: :blueprint,
        title: "Archived Product",
        slug: "archived-product",
        status: :archived
      })

    tag_one = insert(:tag, name: "Onboarding")
    tag_two = insert(:tag, name: "Calculus")

    insert(:section_tag, section: product, tag: tag_one)
    insert(:section_tag, section: product, tag: tag_two)

    conn = log_in_author(conn, admin)

    %{
      conn: conn,
      admin: admin,
      product: product,
      other_product: other_product,
      archived_product: archived_product
    }
  end

  describe "export_csv/2" do
    test "admin can download CSV with all products", %{conn: conn, product: product} do
      conn = get(conn, ~p"/authoring/products/export")

      assert response(conn, 200)

      [content_type] = get_resp_header(conn, "content-type")
      assert content_type == "text/csv"

      csv_content = response(conn, 200)

      assert String.contains?(
               csv_content,
               "Title,Product ID,Tags,Created,Requires Payment,Base Project,Base Project ID,Status"
             )

      assert String.contains?(csv_content, product.title)
      assert String.contains?(csv_content, product.slug)
      assert String.contains?(csv_content, "Calculus")
      assert String.contains?(csv_content, "Onboarding")
    end

    test "respects text search filters", %{
      conn: conn,
      product: product,
      other_product: other_product
    } do
      conn = get(conn, ~p"/authoring/products/export?text_search=#{product.slug}")
      csv_content = response(conn, 200)

      assert String.contains?(csv_content, product.title)
      refute String.contains?(csv_content, other_product.title)
    end

    test "excludes archived products unless explicitly requested", %{
      conn: conn,
      admin: admin,
      archived_product: archived_product
    } do
      conn = get(conn, ~p"/authoring/products/export")
      csv_content = response(conn, 200)
      refute String.contains?(csv_content, archived_product.title)

      conn =
        build_conn()
        |> log_in_author(admin)
        |> get(~p"/authoring/products/export?include_archived=true")

      csv_content = response(conn, 200)
      assert String.contains?(csv_content, archived_product.title)
    end

    test "includes payment data formatted consistently", %{conn: conn, product: product} do
      conn = get(conn, ~p"/authoring/products/export?text_search=#{product.slug}")
      csv_content = response(conn, 200)

      assert String.contains?(csv_content, "$15.00")
    end
  end
end
