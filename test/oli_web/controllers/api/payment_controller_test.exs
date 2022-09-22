defmodule OliWeb.PaymentControllerTest do
  use OliWeb.ConnCase

  import Oli.Factory

  alias Oli.Seeder
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.PaymentController
  alias Oli.Delivery.Paywall

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

      product = insert(:section, %{amount: Money.new(:USD, "50.00")})
      user = insert(:user)

      enrollable =
        insert(:section, %{
          type: :enrollable,
          requires_payment: true,
          blueprint: product,
          amount: Money.new(:USD, "100.00"),
          has_grace_period: true,
          grace_period_days: 2,
          grace_period_strategy: :relative_to_student
        })

      enroll_user_to_section(user, enrollable, :context_learner)

      conn = Pow.Plug.assign_current_user(conn, user, OliWeb.Pow.PowHelpers.get_pow_config(:user))

      conn =
        conn
        |> get(Routes.payment_path(conn, :make_payment, enrollable.slug))

      assert html_response(conn, 200) =~ "<input type=\"text\" disabled value=\"$100.00\"/>"

      reset_test_payment_config()
    end

    test "download a file with the last payment codes created", %{conn: conn} do
      product = insert(:section, %{amount: Money.new(:USD, "50.00")})
      Paywall.create_payment_codes(product.slug, 2)
      codes = Paywall.get_payment_codes(2, product.slug)

      assert response(
               PaymentController.create_payment_codes_file(conn, codes, product.slug),
               200
             )
    end

    test "call 'get_payment_codes/2' return codes for a specific section" do
      product = insert(:section, %{amount: Money.new(:USD, "50.00")})
      Paywall.create_payment_codes(product.slug, 3)
      codes = Paywall.get_payment_codes(3, product.slug)

      assert length(codes) == 3
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
