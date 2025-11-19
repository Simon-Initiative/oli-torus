defmodule OliWeb.PaymentControllerTest do
  use OliWeb.ConnCase

  import Oli.Factory

  alias Oli.Delivery.Sections
  alias Oli.VendorProperties

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

    test "displays default billing descriptor message when pay by card is enabled and billing_descriptor is not set",
         %{
           conn: conn,
           section: section
         } do
      conn = get(conn, ~p"/sections/#{section.slug}/payment")

      html = html_response(conn, 200)

      # Assert that the billing descriptor message appears
      assert html =~ "This charge will appear as"
      assert html =~ "CARNEGIE MELLON UNI"
      assert html =~ "on your statement"

      # Assert that the default billing descriptor is in bold (strong tag)
      assert html =~ "<strong>CARNEGIE MELLON UNI</strong>"

      # Assert that the "Pay by credit card" button appears
      assert html =~ "Pay by credit card"
    end

    test "displays custom billing descriptor when configured", %{
      conn: conn,
      section: section
    } do
      # Set a custom billing descriptor
      original_vendor_property = Application.get_env(:oli, :vendor_property)

      Application.put_env(
        :oli,
        :vendor_property,
        Keyword.merge(Application.get_env(:oli, :vendor_property, []),
          billing_descriptor: "CUSTOM UNIVERSITY"
        )
      )

      on_exit(fn ->
        if is_nil(original_vendor_property) do
          Application.delete_env(:oli, :vendor_property)
        else
          Application.put_env(:oli, :vendor_property, original_vendor_property)
        end
      end)

      conn = get(conn, ~p"/sections/#{section.slug}/payment")

      html = html_response(conn, 200)

      # Assert that the custom billing descriptor appears
      assert html =~ "This charge will appear as"
      assert html =~ "CUSTOM UNIVERSITY"
      assert html =~ "<strong>CUSTOM UNIVERSITY</strong>"
    end

    test "does not display billing descriptor when pay by card is disabled", %{
      conn: conn,
      section: section
    } do
      {:ok, section} =
        Sections.update_section(section, %{
          payment_options: :deferred
        })

      conn = get(conn, ~p"/sections/#{section.slug}/payment")

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
      billing_descriptor = VendorProperties.billing_descriptor()

      {:ok, section} =
        Sections.update_section(section, %{
          payment_options: :direct_and_deferred
        })

      conn = get(conn, ~p"/sections/#{section.slug}/payment")

      html = html_response(conn, 200)

      # Assert that the billing descriptor message appears
      assert html =~ "This charge will appear as"
      assert html =~ "<strong>#{billing_descriptor}</strong>"
      assert html =~ "on your statement"

      # Assert that both payment options are available
      assert html =~ "Pay by credit card"
      assert html =~ "Pay using a Payment Code"
    end

    test "redirects to login when user is not authenticated", %{section: section} do
      conn = build_conn() |> get(~p"/sections/#{section.slug}/payment")

      assert html_response(conn, 302) =~
               "You are being <a href=\"/users/log_in\">redirected"
    end

    test "displays not enrolled message when user is not enrolled", %{section: section} do
      other_user = insert(:user)
      conn = log_in_user(build_conn(), other_user)

      conn = get(conn, ~p"/sections/#{section.slug}/payment")

      assert html_response(conn, 200) =~ "You are not enrolled in this course section"
    end

    test "displays require account page with correct login link for guest users", %{
      section: section
    } do
      guest_user = insert(:user, guest: true)
      insert(:enrollment, %{user: guest_user, section: section})

      conn = log_in_user(build_conn(), guest_user)
      conn = get(conn, ~p"/sections/#{section.slug}/payment")

      html = html_response(conn, 200)

      # Assert that the require account page is displayed
      assert html =~ "Payment and Account Required"
      assert html =~ "You are currently accessing the system as a guest"

      # Assert that the login link redirects to enrollment page, not payment page
      assert html =~ "/users/log_in?"
      assert html =~ URI.encode_query(%{request_path: "/sections/#{section.slug}/enroll"})
      assert html =~ "Sign in / Create an account"
    end

    test "guest user can sign in and be redirected to enrollment page", %{section: section} do
      # Create a regular (non-guest) user who will sign in
      regular_user = user_fixture()

      # Create a guest user and access the payment page as guest
      guest_user = insert(:user, guest: true)
      insert(:enrollment, %{user: guest_user, section: section})

      conn = log_in_user(build_conn(), guest_user)
      conn = get(conn, ~p"/sections/#{section.slug}/payment")

      # Extract the login link from the page
      html = html_response(conn, 200)
      assert html =~ "/users/log_in?request_path="

      # Now sign in as a regular user
      conn = build_conn()

      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{
            "email" => regular_user.email,
            "password" => valid_user_password()
          },
          "request_path" => "/sections/#{section.slug}/enroll"
        })

      # Should redirect to the enrollment page
      assert redirected_to(conn) == "/sections/#{section.slug}/enroll"
    end
  end

  describe "request_path validation for open redirect prevention" do
    setup do
      {:ok, user: user_fixture()}
    end

    test "prevents open redirect attacks via absolute URLs", %{user: user} do
      conn =
        post(build_conn(), ~p"/users/log_in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          },
          "request_path" => "https://evil.com/phishing"
        })

      # Should NOT redirect to the malicious URL, should go to default (student workspace)
      assert redirected_to(conn) == ~p"/workspaces/student"
    end

    test "prevents protocol-relative URL attacks", %{user: user} do
      conn =
        post(build_conn(), ~p"/users/log_in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          },
          "request_path" => "//evil.com/phishing"
        })

      # Should NOT redirect to the protocol-relative URL
      assert redirected_to(conn) == ~p"/workspaces/student"
    end

    test "rejects paths with leading whitespace as suspicious", %{user: user} do
      conn =
        post(build_conn(), ~p"/users/log_in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          },
          "request_path" => " /sections/some-section/enroll"
        })

      # Should reject the path with whitespace and use default redirect
      assert redirected_to(conn) == ~p"/workspaces/student"
    end

    test "allows valid internal paths", %{user: user} do
      conn =
        post(build_conn(), ~p"/users/log_in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          },
          "request_path" => "/sections/test-section/enroll"
        })

      # Should redirect to the valid internal path
      assert redirected_to(conn) == "/sections/test-section/enroll"
    end
  end
end
