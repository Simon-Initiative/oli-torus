defmodule OliWeb.PaymentControllerTest do
  use OliWeb.ConnCase

  import Oli.Factory

  alias Oli.Seeder
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Delivery.Paywall.Payment

  defp generate_payment_code(product, code) do
    :payment
    |> insert(section: product, code: code)
    |> Map.get(:code)
    |> Payment.to_human_readable()
  end

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

    test "direct payment shows section's cost", %{
      conn: conn
    } do
      load_stripe_config()

      product = insert(:section, %{amount: Money.new(50, "USD")})
      user = insert(:user)

      enrollable =
        insert(:section, %{
          type: :enrollable,
          requires_payment: true,
          blueprint: product,
          amount: Money.new(100, "USD"),
          has_grace_period: true,
          grace_period_days: 2,
          grace_period_strategy: :relative_to_student
        })

      enroll_user_to_section(user, enrollable, :context_learner)

      conn = log_in_user(conn, user)

      conn =
        conn
        |> get(Routes.payment_path(conn, :make_payment, enrollable.slug))

      assert html_response(conn, 200) =~ "$100.00"

      reset_test_payment_config()
    end

    test "download .txt file with the last payment codes created", %{conn: conn} do
      product =
        insert(:section, %{
          type: :blueprint
        })

      {:ok, conn: conn, admin: _admin} = admin_conn(%{conn: conn})

      code1 = generate_payment_code(product, 123_456_789)

      code2 = generate_payment_code(product, 987_654_321)

      code3 = generate_payment_code(product, 111_111_111)

      # Simulate response with 2 payment codes
      conn_with_codes =
        get(
          conn,
          Routes.payment_path(OliWeb.Endpoint, :download_payment_codes, product.slug, count: 2)
        )

      assert response(conn_with_codes, 200) =~ "#{code3}\n#{code2}"

      # Simulate response with 0 payment codes
      conn_without_codes =
        get(
          conn,
          Routes.payment_path(OliWeb.Endpoint, :download_payment_codes, product.slug, count: 0)
        )

      assert response(conn_without_codes, 200) =~ ""

      # Simulate response without sending the amount of payment codes
      conn_without_count =
        get(
          conn,
          Routes.payment_path(OliWeb.Endpoint, :download_payment_codes, product.slug)
        )

      assert response(conn_without_count, 200) =~ "#{code3}\n#{code2}\n#{code1}"
    end

    test "download .txt file of a product that has no payment codes generated", %{conn: conn} do
      product =
        insert(:section, %{
          type: :blueprint
        })

      {:ok, conn: conn, admin: _admin} = admin_conn(%{conn: conn})

      conn =
        get(
          conn,
          Routes.payment_path(OliWeb.Endpoint, :download_payment_codes, product.slug, count: 2)
        )

      assert response(conn, 200) =~ ""
    end
  end

  defp setup_session(%{conn: conn}) do
    stub_real_current_time()

    map =
      Seeder.base_project_with_resource2()
      |> Seeder.create_product(%{title: "My 1st product", amount: Money.new(100, "USD")}, :prod1)
      |> Seeder.create_product(
        %{title: "My 2nd product", amount: Money.from_float("USD", 24.99)},
        :prod2
      )

    conn = Plug.Test.init_test_session(conn, lti_session: nil)

    api_key = UUID.uuid4()
    {:ok, key} = Oli.Interop.create_key(api_key, "hint")

    {:ok, conn: conn, map: map, api_key: api_key, key: key}
  end
end
