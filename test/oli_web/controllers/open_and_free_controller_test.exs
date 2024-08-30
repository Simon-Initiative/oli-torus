defmodule OliWeb.OpenAndFreeControllerTest do
  use OliWeb.ConnCase

  @create_attrs %{
    end_date: ~U[2010-04-17 00:00:00.000000Z],
    open_and_free: true,
    registration_open: true,
    start_date: ~U[2010-04-17 00:00:00.000000Z],
    title: "some title",
    context_id: "some context_id"
  }

  @invalid_attrs %{
    end_date: nil,
    open_and_free: nil,
    registration_open: nil,
    start_date: nil,
    title: nil,
    context_id: nil
  }

  describe "create independent section" do
    setup [:create_project_with_products, :instructor_conn]

    test "show create form for product", %{
      conn: conn,
      product_1: product_1
    } do
      conn =
        get(conn, ~p"/sections/independent/new?source_id=product%3A#{product_1.id}")

      assert html_response(conn, 200) =~ "Create Section"

      assert html_response(conn, 200) =~
               "<input id=\"section_source_id\" name=\"section[source_id]\" type=\"hidden\" value=\"product:#{product_1.id}\">"

      assert html_response(conn, 200) =~ "<input type=\"text\" value=\"Product 1\""
    end

    test "create section from product redirects to instructor dashboard manage page", %{
      conn: conn,
      product_1: product_1
    } do
      conn =
        post(conn, ~p"/sections/independent",
          section:
            Enum.into(@create_attrs, %{
              product_slug: product_1.slug,
              source_id: "product:#{product_1.id}"
            })
        )

      %{section_slug: section_slug} = redirected_params(conn)

      assert redirected_to(conn) == ~p"/sections/#{section_slug}/manage"
    end

    test "renders errors when data is invalid", %{
      conn: conn,
      product_1: product_1
    } do
      conn =
        post(conn, ~p"/sections/independent",
          section:
            Enum.into(@invalid_attrs, %{
              product_slug: product_1.slug,
              source_id: "product:#{product_1.id}"
            })
        )

      assert html_response(conn, 200) =~ "Create Section"
    end
  end
end
