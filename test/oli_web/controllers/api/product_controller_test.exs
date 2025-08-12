defmodule OliWeb.ProductControllerTest do
  @moduledoc false

  use OliWeb.ConnCase

  alias Oli.Inventories
  alias Oli.Seeder

  describe "index" do
    setup [:setup_session]

    test "lists all products", %{
      conn: conn,
      api_key: api_key,
      map: map
    } do
      publisher_id = Inventories.default_publisher().id

      prod1 = map.prod1
      prod2 = map.prod2

      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> Base.encode64(api_key))
        |> get(Routes.product_path(conn, :index))

      assert json_response(conn, 200)["products"] |> Enum.count() == 2

      assert json_response(conn, 200)["products"]
             |> Enum.find(fn p ->
               p == %{
                 "amount" => Money.to_string!(prod1.amount),
                 "description" => "a description",
                 "grace_period_days" => prod1.grace_period_days,
                 "grace_period_strategy" => Atom.to_string(prod1.grace_period_strategy),
                 "has_grace_period" => prod1.has_grace_period,
                 "requires_payment" => prod1.requires_payment,
                 "pay_by_institution" => prod1.pay_by_institution,
                 "slug" => prod1.slug,
                 "status" => Atom.to_string(prod1.status),
                 "title" => prod1.title,
                 "publisher_id" => publisher_id,
                 "cover_image" => "https://someurl.com/some-image.png"
               }
             end)

      assert json_response(conn, 200)["products"]
             |> Enum.find(fn p ->
               p == %{
                 "amount" => nil,
                 "description" => nil,
                 "grace_period_days" => 0,
                 "grace_period_strategy" => Atom.to_string(prod2.grace_period_strategy),
                 "has_grace_period" => prod2.has_grace_period,
                 "requires_payment" => prod2.requires_payment,
                 "pay_by_institution" => prod1.pay_by_institution,
                 "slug" => prod2.slug,
                 "status" => Atom.to_string(prod2.status),
                 "title" => prod2.title,
                 "publisher_id" => publisher_id,
                 "cover_image" => nil
               }
             end)
    end

    test "renders error when api key does not have product scope", %{
      conn: conn,
      api_key: api_key,
      key: key
    } do
      conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer " <> Base.encode64(api_key))

      Oli.Interop.update_key(key, %{products_enabled: false})

      conn = get(conn, Routes.product_path(conn, :index))

      assert response(conn, 401)
    end

    test "renders error when api key has been disabled", %{
      conn: conn,
      api_key: api_key,
      key: key
    } do
      conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer " <> Base.encode64(api_key))

      Oli.Interop.update_key(key, %{status: :disabled})

      conn = get(conn, Routes.product_path(conn, :index))

      assert response(conn, 401)
    end
  end

  defp setup_session(%{conn: conn}) do
    map =
      Seeder.base_project_with_resource2()
      |> Seeder.create_product(
        %{
          title: "My 1st product",
          amount: Money.new(100, "USD"),
          requires_payment: true,
          grace_period_days: 14,
          cover_image: "https://someurl.com/some-image.png"
        },
        :prod1
      )
      |> Seeder.create_product(
        %{title: "My 2nd product", amount: Money.from_float("USD", 24.99), description: nil},
        :prod2
      )

    conn = Plug.Test.init_test_session(conn, lti_session: nil)

    api_key = UUID.uuid4()
    {:ok, key} = Oli.Interop.create_key(api_key, "hint")

    {:ok, conn: conn, map: map, api_key: api_key, key: key}
  end
end
