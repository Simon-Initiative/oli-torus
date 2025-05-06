defmodule OliWeb.UserRegistrationLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Create account"
      assert html =~ "Sign in"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/register")
        |> follow_redirect(conn, "/workspaces/student")

      assert {:ok, _conn} = result
    end

    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "with spaces", "password" => "too short"})

      assert result =~ "Create account"
      assert result =~ "must have the @ sign and no spaces"
      assert result =~ "should be at least 12 character"
    end
  end

  describe "register user" do
    test "creates account and logs the user in", %{conn: conn} do
      stub_recaptcha()

      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()

      form =
        form(lv, "#registration_form",
          user: %{
            "email" => email,
            "given_name" => "Andrew",
            "family_name" => "Carnegie",
            "password" => "valid_password",
            "password_confirmation" => "valid_password"
          }
        )

      render_submit(form)
      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == ~p"/workspaces/student"

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/")
      response = html_response(conn, 200)

      assert response =~ "Access my courses"
    end

    test "renders errors for duplicated email", %{conn: conn} do
      stub_recaptcha()

      {:ok, lv, _html} = live(conn, ~p"/users/register")

      user = user_fixture(%{email: "test@email.com", independent_learner: true})

      result =
        lv
        |> form("#registration_form",
          user: %{
            "email" => user.email,
            "password" => "valid_password",
            "password_confirmation" => "valid_password"
          }
        )
        |> render_submit()

      assert result =~ "has already been taken"
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Sign in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      {:ok, conn} =
        lv
        |> element(~s|a:fl-contains("Sign in to existing account")|)
        |> render_click()
        |> follow_redirect(conn, ~p"/users/log_in")

      assert html_response(conn, 200) =~ "Sign in"
    end
  end
end
