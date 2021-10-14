defmodule OliWeb.ProductControllerTest do
  use OliWeb.ConnCase

  alias Oli.Seeder

  describe "product controller tests" do
    setup [:setup_session]

    test "can fetch all products", %{
      conn: conn,
      api_key: api_key
    } do
      conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer " <> Base.encode64(api_key))

      conn =
        get(
          conn,
          Routes.product_path(conn, :index)
        )

      assert %{"result" => "success", "products" => products} = json_response(conn, 200)
      assert length(products) == 2
      assert Enum.find(products, fn p -> p["amount"] == "$100.00" end)
      assert Enum.find(products, fn p -> p["amount"] == "$24.99" end)
    end

    test "request fails when api key does not have product scope", %{
      conn: conn,
      api_key: api_key,
      key: key
    } do
      conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer " <> Base.encode64(api_key))

      Oli.Interop.update_key(key, %{products_enabled: false})

      conn =
        get(
          conn,
          Routes.product_path(conn, :index)
        )

      assert response(conn, 401)
    end

    test "request fails when api key has been disabled", %{
      conn: conn,
      api_key: api_key,
      key: key
    } do
      conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer " <> Base.encode64(api_key))

      Oli.Interop.update_key(key, %{status: :disabled})

      conn =
        get(
          conn,
          Routes.product_path(conn, :index)
        )

      assert response(conn, 401)
    end
  end

  defp setup_session(%{conn: conn}) do
    map =
      Seeder.base_project_with_resource2()
      |> Seeder.create_product(%{title: "My 1st product", amount: Money.new(:USD, 100)}, :prod1)
      |> Seeder.create_product(
        %{title: "My 2nd product", amount: Money.new(:USD, "24.99")},
        :prod2
      )

    conn = Plug.Test.init_test_session(conn, lti_session: nil)

    api_key = UUID.uuid4()
    {:ok, key} = Oli.Interop.create_key(api_key, "hint")

    {:ok, conn: conn, map: map, api_key: api_key, key: key}
  end
end
