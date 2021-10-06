defmodule OliWeb.PaymentControllerTest do
  use OliWeb.ConnCase

  alias Oli.Seeder

  describe "payment controller tests" do
    setup [:setup_session]

    test "can create batches of payment codes", %{
      conn: conn,
      map: map,
      api_key: api_key
    } do
      conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer " <> Base.encode64(api_key))

      conn =
        post(
          conn,
          Routes.payment_path(conn, :new),
          %{"product_slug" => map.prod1.slug, "batch_size" => 50}
        )

      assert %{"result" => "success", "codes" => codes} = json_response(conn, 200)
      assert length(codes) == 50
    end

    test "invalid product code fails", %{
      conn: conn,
      api_key: api_key
    } do
      conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer " <> Base.encode64(api_key))

      conn =
        post(
          conn,
          Routes.payment_path(conn, :new),
          %{"product_slug" => "this_slug_does_not_exist", "batch_size" => 50}
        )

      assert response(conn, 404)
    end

    test "batch size fails when too large", %{
      conn: conn,
      map: map,
      api_key: api_key
    } do
      conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer " <> Base.encode64(api_key))

      conn =
        post(
          conn,
          Routes.payment_path(conn, :new),
          %{"product_slug" => map.prod1.slug, "batch_size" => 5000}
        )

      assert response(conn, 400)
    end

    test "batch size fails when too small", %{
      conn: conn,
      map: map,
      api_key: api_key
    } do
      conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer " <> Base.encode64(api_key))

      conn =
        post(
          conn,
          Routes.payment_path(conn, :new),
          %{"product_slug" => map.prod1.slug, "batch_size" => 0}
        )

      assert response(conn, 400)
    end

    test "request fails when api key has been disabled", %{
      conn: conn,
      map: map,
      api_key: api_key,
      key: key
    } do
      conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer " <> Base.encode64(api_key))

      Oli.Interop.update_key(key, %{status: :disabled})

      conn =
        post(
          conn,
          Routes.payment_path(conn, :new),
          %{"product_slug" => map.prod1.slug, "batch_size" => 10}
        )

      assert response(conn, 401)
    end

    test "request fails when api key does not have payment scope", %{
      conn: conn,
      map: map,
      api_key: api_key,
      key: key
    } do
      conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer " <> Base.encode64(api_key))

      Oli.Interop.update_key(key, %{payments_enabled: false})

      conn =
        post(
          conn,
          Routes.payment_path(conn, :new),
          %{"product_slug" => map.prod1.slug, "batch_size" => 10}
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
