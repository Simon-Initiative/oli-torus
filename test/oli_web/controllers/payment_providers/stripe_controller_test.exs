defmodule OliWeb.PaymentProviders.StripeControllerTest do
  use OliWeb.ConnCase

  import Mox
  import Oli.Factory

  alias Oli.Delivery.Paywall
  alias Oli.Delivery.Paywall.Providers.Stripe
  alias Oli.Test.MockHTTP

  @stripe_payments_intents_url "https://api.stripe.com/v1/payment_intents"

  defp load_stripe_config(_) do
    Config.Reader.read!("test/config/stripe_config.exs")
    |> Application.put_all_env()
  end

  defp create_section(_) do
    section =
      insert(:section, %{
        type: :enrollable,
        open_and_free: true,
        requires_enrollment: true,
        requires_payment: true,
        amount: Money.new(:USD, 25)
      })

    [section: section]
  end

  describe "user cannot direct pay when stripe is not configured" do
    setup [:user_conn, :create_section]

    test "displays not enabled message", %{conn: conn, user: user, section: section} do
      Config.Reader.read!("test/config/config.exs")
      |> Application.put_all_env()

      insert(:enrollment, %{user: user, section: section})


      conn = get(conn, Routes.payment_path(conn, :make_payment, section.slug))

      assert html_response(conn, 200) =~ "Direct payments are not enabled"
    end
  end

  describe "user cannot access when is not logged in" do
    setup [:load_stripe_config, :create_section]

    test "redirects to new session when accessing the show view", %{conn: conn, section: section} do
      conn = get(conn, Routes.payment_path(conn, :make_payment, section.slug))

      assert html_response(conn, 302) =~
               "You are being <a href=\"/session/new?request_path=%2Fsections%2F#{section.slug}%2Fpayment%2Fnew&amp;section=#{section.slug}\">redirected"
    end

    test "redirects to new session when trying to init intent", %{conn: conn, section: section} do
      conn =
        post(conn, Routes.stripe_path(conn, :init_intent), %{
          section_slug: section.slug
        })

      assert html_response(conn, 302) =~ "You are being <a href=\"/session/new\">redirected"
    end

    test "redirects to new session when trying to hit failure", %{conn: conn} do
      conn = post(conn, Routes.stripe_path(conn, :failure))

      assert html_response(conn, 302) =~ "You are being <a href=\"/session/new\">redirected"
    end

    test "redirects to new session when trying to hit success", %{conn: conn} do
      conn = post(conn, Routes.stripe_path(conn, :success), %{:intent => %{}})

      assert html_response(conn, 302) =~ "You are being <a href=\"/session/new\">redirected"
    end
  end

  describe "show (through payment controller)" do
    setup [:user_conn, :load_stripe_config, :create_section]

    test "can access if user already paid", %{conn: conn, user: user, section: section} do
      enrollment = insert(:enrollment, %{user: user, section: section})
      insert(:payment, %{section: section, enrollment: enrollment})

      conn = get(conn, Routes.payment_path(conn, :make_payment, section.slug))

      assert html_response(conn, 302) =~
               "You are being <a href=\"/sections/#{section.slug}/overview\">redirected"
    end

    test "displays stripe form", %{conn: conn, section: section, user: user} do

      insert(:enrollment, %{user: user, section: section})

      {:ok, amount} = Money.to_string(section.amount)

      conn = get(conn, Routes.payment_path(conn, :make_payment, section.slug))

      assert html_response(conn, 200) =~ "Course Section"
      assert html_response(conn, 200) =~ "value=\"#{section.title}\""
      assert html_response(conn, 200) =~ "User"
      assert html_response(conn, 200) =~ "value=\"#{user.family_name}, #{user.given_name}\""
      assert html_response(conn, 200) =~ "Amount"
      assert html_response(conn, 200) =~ "value=\"#{amount}\""
      assert html_response(conn, 200) =~ "id=\"card-element\""
    end
  end

  @moduletag :capture_log
  describe "init intent" do
    setup [:user_conn, :create_section]

    test "return unauthorized if user is not enrolled", %{
      conn: conn,
      user: user,
      section: section
    } do
      conn =
        post(conn, Routes.stripe_path(conn, :init_intent), %{
          user_id: user.id,
          section_slug: section.slug
        })

      assert response(conn, 401) =~
               "unauthorized, this user is not enrolled in this section"
    end

    test "fails when stripe api call fails", %{
      conn: conn,
      user: user,
      section: section
    } do
      insert(:enrollment, %{user: user, section: section})

      MockHTTP
      |> expect(:post, fn @stripe_payments_intents_url, _body, _headers ->
        {:ok,
         %HTTPoison.Response{
           status_code: 500
         }}
      end)

      conn =
        post(conn, Routes.stripe_path(conn, :init_intent), %{
          user_id: user.id,
          section_slug: section.slug
        })

      assert response(conn, 500) =~
               "StripeController:init_intent failed.. Please try again or contact support with issue"
    end

    test "intent creation succeeds", %{
      conn: conn,
      user: user,
      section: section
    } do
      insert(:enrollment, %{user: user, section: section})

      MockHTTP
      |> expect(:post, fn @stripe_payments_intents_url, _body, _headers ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: "{ \"client_secret\": \"secret\", \"id\": \"test_id\" }"
         }}
      end)

      conn =
        post(conn, Routes.stripe_path(conn, :init_intent), %{
          user_id: user.id,
          section_slug: section.slug
        })

      assert response(conn, 200) =~
               "{\"clientSecret\":\"secret\"}"

      pending_payment = Paywall.get_provider_payment(:stripe, "test_id")
      assert pending_payment
      refute pending_payment.application_date
      assert pending_payment.pending_section_id == section.id
      assert pending_payment.pending_user_id == user.id
      assert pending_payment.section_id == section.id
      assert pending_payment.provider_type == :stripe
      assert pending_payment.provider_id == "test_id"
    end

    test "intent creation succeeds with section created from product", %{
      conn: conn,
      user: user
    } do
      product = insert(:section)

      section =
        insert(:section, %{
          type: :enrollable,
          open_and_free: true,
          requires_enrollment: true,
          requires_payment: true,
          amount: Money.new(:USD, 25),
          blueprint: product
        })

      insert(:enrollment, %{user: user, section: section})

      MockHTTP
      |> expect(:post, fn @stripe_payments_intents_url, _body, _headers ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: "{ \"client_secret\": \"secret\", \"id\": \"test_id\" }"
         }}
      end)

      conn =
        post(conn, Routes.stripe_path(conn, :init_intent), %{
          user_id: user.id,
          section_slug: section.slug
        })

      assert response(conn, 200) =~
               "{\"clientSecret\":\"secret\"}"

      pending_payment = Paywall.get_provider_payment(:stripe, "test_id")
      assert pending_payment
      refute pending_payment.application_date
      assert pending_payment.pending_section_id == section.id
      assert pending_payment.pending_user_id == user.id
      assert pending_payment.section_id == product.id
      assert pending_payment.provider_type == :stripe
      assert pending_payment.provider_id == "test_id"
    end
  end

  @moduletag :capture_log
  describe "failure" do
    setup [:user_conn]

    test "return success", %{
      conn: conn
    } do
      conn = post(conn, Routes.stripe_path(conn, :failure))

      assert response(conn, 200) =~
               "{\"result\":\"success\"}"
    end
  end

  @moduletag :capture_log
  describe "success" do
    setup [:user_conn, :create_section]

    test "return not found when intent does not exists", %{
      conn: conn
    } do
      conn =
        post(conn, Routes.stripe_path(conn, :success), %{
          :intent => %{id: "something"}
        })

      assert response(conn, 200) =~
               "{\"reason\":\"Payment does not exist\",\"result\":\"failure\"}"
    end

    test "intent confirmation succeeds", %{
      conn: conn,
      user: user,
      section: section
    } do
      enrollment = insert(:enrollment, %{user: user, section: section})

      MockHTTP
      |> expect(:post, fn @stripe_payments_intents_url, _body, _headers ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: "{ \"client_secret\": \"secret\", \"id\": \"test_id\" }"
         }}
      end)

      {:ok, intent} = Stripe.create_intent(Money.new(:USD, 100), user, section, section)

      conn =
        post(conn, Routes.stripe_path(conn, :success), %{
          :intent => intent
        })

      assert response(conn, 200) =~
               "{\"result\":\"success\",\"url\":\"/sections/#{section.slug}/overview\"}"

      finalized = Paywall.get_provider_payment(:stripe, "test_id")
      assert finalized
      assert finalized.enrollment_id == enrollment.id
      assert finalized.application_date
      assert finalized.pending_section_id == section.id
      assert finalized.pending_user_id == user.id
      assert finalized.section_id == section.id
      assert finalized.provider_type == :stripe
      assert finalized.provider_id == "test_id"
    end

    test "intent confirmation succeeds with section created from product", %{
      conn: conn,
      user: user
    } do
      product = insert(:section)

      section =
        insert(:section, %{
          type: :enrollable,
          open_and_free: true,
          requires_enrollment: true,
          requires_payment: true,
          amount: Money.new(:USD, 25),
          blueprint: product
        })

      enrollment = insert(:enrollment, %{user: user, section: section})

      MockHTTP
      |> expect(:post, fn @stripe_payments_intents_url, _body, _headers ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: "{ \"client_secret\": \"secret\", \"id\": \"test_id\" }"
         }}
      end)

      {:ok, intent} = Stripe.create_intent(Money.new(:USD, 100), user, section, product)

      conn =
        post(conn, Routes.stripe_path(conn, :success), %{
          :intent => intent
        })

      assert response(conn, 200) =~
               "{\"result\":\"success\",\"url\":\"/sections/#{section.slug}/overview\"}"

      finalized = Paywall.get_provider_payment(:stripe, "test_id")
      assert finalized
      assert finalized.enrollment_id == enrollment.id
      assert finalized.application_date
      assert finalized.pending_section_id == section.id
      assert finalized.pending_user_id == user.id
      assert finalized.section_id == product.id
      assert finalized.provider_type == :stripe
      assert finalized.provider_id == "test_id"
    end

    test "intent confirmation fails when is already confirmed", %{
      conn: conn,
      user: user,
      section: section
    } do
      insert(:enrollment, %{user: user, section: section})

      MockHTTP
      |> expect(:post, fn @stripe_payments_intents_url, _body, _headers ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: "{ \"client_secret\": \"secret\", \"id\": \"test_id\" }"
         }}
      end)

      {:ok, intent} = Stripe.create_intent(Money.new(:USD, 100), user, section, section)
      assert {:ok, _} = Stripe.finalize_payment(intent)

      conn =
        post(conn, Routes.stripe_path(conn, :success), %{
          :intent => intent
        })

      assert response(conn, 200) =~
               "{\"reason\":\"Payment already finalized\",\"result\":\"failure\"}"
    end
  end
end
