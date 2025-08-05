defmodule OliWeb.PaymentProviders.CashnetControllerTest do
  use OliWeb.ConnCase

  import Oli.Factory

  alias Oli.Delivery.Paywall

  defp create_section(), do: create_section(nil)

  defp create_section(_) do
    section =
      insert(:section, %{
        type: :enrollable,
        open_and_free: true,
        requires_enrollment: true,
        requires_payment: true,
        amount: Money.new(25, "USD")
      })

    [section: section]
  end

  describe "user cannot direct pay when cashnet is not configured" do
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
    setup do
      load_cashnet_config()
      on_exit(fn -> reset_test_payment_config() end)
      create_section()
    end

    test "redirects to new session when accessing the show view", %{conn: conn, section: section} do
      conn = get(conn, Routes.payment_path(conn, :make_payment, section.slug))

      assert html_response(conn, 302) =~
               "You are being <a href=\"/users/log_in\">redirected"

      assert Plug.Conn.get_session(conn, :user_return_to) ==
               Routes.payment_path(conn, :make_payment, section.slug)
    end

    test "redirects to new session when trying to init form", %{conn: conn, section: section} do
      conn =
        post(conn, Routes.cashnet_path(conn, :init_form), %{
          section_slug: section.slug
        })

      assert html_response(conn, 302) =~ "You are being <a href=\"/users/log_in\">redirected"
    end
  end

  describe "show (through payment controller)" do
    setup attrs do
      [section: section] = create_section()
      {:ok, conn: conn, user: user} = user_conn(attrs)
      load_cashnet_config()

      on_exit(fn -> reset_test_payment_config() end)

      [conn: conn, user: user, section: section]
    end

    test "can access if user already paid", %{conn: conn, user: user, section: section} do
      enrollment = insert(:enrollment, %{user: user, section: section})
      insert(:payment, %{section: section, enrollment: enrollment})

      conn = get(conn, Routes.payment_path(conn, :make_payment, section.slug))

      assert html_response(conn, 302) =~
               "You are being <a href=\"/sections/#{section.slug}\">redirected"
    end
  end

  @moduletag :capture_log
  describe "init intent" do
    setup [:user_conn, :create_section]

    test "displays not enrolled message when not enrolled", %{
      conn: conn
    } do
      product = insert(:section)

      section =
        insert(:section, %{
          type: :enrollable,
          open_and_free: true,
          requires_enrollment: true,
          requires_payment: true,
          amount: Money.new(25, "USD"),
          blueprint: product
        })

      conn = get(conn, Routes.payment_path(conn, :guard, section.slug))
      assert html_response(conn, 200) =~ "You are not enrolled in this course section"
    end

    test "return unauthorized if user is not enrolled", %{
      conn: conn,
      user: user,
      section: section
    } do
      conn =
        post(conn, Routes.cashnet_path(conn, :init_form), %{
          user_id: user.id,
          section_slug: section.slug
        })

      assert response(conn, 401) =~
               "unauthorized, this user is not enrolled in this section"
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
          amount: Money.new(25, "USD"),
          blueprint: product
        })

      insert(:enrollment, %{user: user, section: section})

      conn =
        post(conn, Routes.cashnet_path(conn, :init_form), %{
          user_id: user.id,
          section_slug: section.slug
        })

      %{"paymentRef" => payment_ref} = json_response(conn, 200)

      pending_payment = Paywall.get_provider_payment(:cashnet, payment_ref)
      assert pending_payment
      refute pending_payment.application_date
      assert pending_payment.pending_section_id == section.id
      assert pending_payment.pending_user_id == user.id
      assert pending_payment.section_id == section.id
      assert pending_payment.provider_type == :cashnet
      assert pending_payment.provider_id == payment_ref
    end
  end

  @moduletag :capture_log
  describe "success" do
    setup [:user_conn, :create_section]

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
          amount: Money.new(25, "USD"),
          blueprint: product
        })

      enrollment = insert(:enrollment, %{user: user, section: section})

      conn =
        post(conn, Routes.cashnet_path(conn, :init_form), %{
          user_id: user.id,
          section_slug: section.slug
        })

      %{"paymentRef" => payment_ref} = json_response(conn, 200)

      conn =
        post(conn, Routes.cashnet_path(conn, :success), %{
          "result" => "0",
          "respmessage" => "SUCCESS",
          "lname" => System.get_env("CASHNET_NAME", "none"),
          "ref1val1" => payment_ref
        })

      assert response(conn, 200) =~
               "{\"result\":\"success\"}"

      finalized = Paywall.get_provider_payment(:cashnet, payment_ref)
      assert finalized
      assert finalized.enrollment_id == enrollment.id
      assert finalized.application_date
      assert finalized.pending_section_id == section.id
      assert finalized.pending_user_id == user.id
      assert finalized.section_id == section.id
      assert finalized.provider_type == :cashnet
      assert finalized.provider_id == payment_ref
    end
  end
end
