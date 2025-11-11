defmodule OliWeb.PaymentControllerTest do
  use OliWeb.ConnCase

  import Oli.Factory

  alias Oli.Delivery.Sections

  describe "guard action" do
    setup do
      load_stripe_config()
      on_exit(fn -> reset_test_payment_config() end)

      user = insert(:user)

      section =
        insert(:section, %{
          type: :enrollable,
          open_and_free: true,
          requires_enrollment: true,
          requires_payment: true,
          payment_options: :direct,
          amount: Money.new(100, "USD")
        })

      insert(:enrollment, %{user: user, section: section})

      conn = log_in_user(build_conn(), user)

      {:ok, conn: conn, user: user, section: section}
    end

    test "displays billing descriptor message when pay by card is enabled", %{
      conn: conn,
      section: section
    } do
      conn = get(conn, Routes.payment_path(conn, :guard, section.slug))

      html = html_response(conn, 200)

      # Assert that the billing descriptor message appears
      assert html =~ "This charge will appear as"
      assert html =~ "CARNEGIE MELLON UNI"
      assert html =~ "on your statement"

      # Assert that "CARNEGIE MELLON UNI" is in bold (strong tag)
      assert html =~ "<strong>CARNEGIE MELLON UNI</strong>"

      # Assert that the "Pay by credit card" button appears
      assert html =~ "Pay by credit card"
    end

    test "does not display billing descriptor when pay by card is disabled", %{
      conn: conn,
      section: section
    } do
      {:ok, section} =
        Sections.update_section(section, %{
          payment_options: :deferred
        })

      conn = get(conn, Routes.payment_path(conn, :guard, section.slug))

      html = html_response(conn, 200)

      # Assert that the billing descriptor message does not appear
      refute html =~ "This charge will appear as"
      refute html =~ "CARNEGIE MELLON UNI"

      # Assert that payment code form appears instead
      assert html =~ "Pay using a Payment Code"
    end

    test "displays billing descriptor when both payment options are enabled", %{
      conn: conn,
      section: section
    } do
      {:ok, section} =
        Sections.update_section(section, %{
          payment_options: :direct_and_deferred
        })

      conn = get(conn, Routes.payment_path(conn, :guard, section.slug))

      html = html_response(conn, 200)

      # Assert that the billing descriptor message appears
      assert html =~ "This charge will appear as"
      assert html =~ "<strong>CARNEGIE MELLON UNI</strong>"
      assert html =~ "on your statement"

      # Assert that both payment options are available
      assert html =~ "Pay by credit card"
      assert html =~ "Pay using a Payment Code"
    end

    test "redirects to login when user is not authenticated", %{section: section} do
      conn = build_conn() |> get(Routes.payment_path(build_conn(), :guard, section.slug))

      assert html_response(conn, 302) =~
               "You are being <a href=\"/users/log_in\">redirected"
    end

    test "displays not enrolled message when user is not enrolled", %{section: section} do
      other_user = insert(:user)
      conn = log_in_user(build_conn(), other_user)

      conn = get(conn, Routes.payment_path(conn, :guard, section.slug))

      assert html_response(conn, 200) =~ "You are not enrolled in this course section"
    end
  end
end
