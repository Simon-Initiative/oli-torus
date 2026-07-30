defmodule OliWeb.AuthorRegistrationLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/authors/register")

      assert html =~ "Create account"
      assert html =~ "Sign in"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_author(author_fixture())
        |> live(~p"/authors/register")
        |> follow_redirect(conn, "/workspaces/course_author")

      assert {:ok, _conn} = result
    end

    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/authors/register")

      result =
        lv
        |> element("#registration_form")
        |> render_change(author: %{"email" => "with spaces", "password" => "too short"})

      assert result =~ "Create account"
      assert result =~ "must be a valid email address"
      assert result =~ "should be at least 12 character"
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Sign in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/authors/register")

      {:ok, conn} =
        lv
        |> element("a", "Sign in to existing account")
        |> render_click()
        |> follow_redirect(conn, ~p"/authors/log_in")

      assert html_response(conn, 200) =~ "Sign in"
    end
  end

  describe "register author" do
    test "confirms and redirects the author when email verification is disabled", %{conn: conn} do
      stub_recaptcha()
      previous = Application.get_env(:oli, :author_email_verification_required)
      Application.put_env(:oli, :author_email_verification_required, false)

      on_exit(fn ->
        Application.put_env(:oli, :author_email_verification_required, previous)
      end)

      {:ok, lv, _html} = live(conn, ~p"/authors/register")
      email = unique_author_email()

      form =
        form(lv, "#registration_form",
          author: %{
            "email" => email,
            "given_name" => "Ada",
            "family_name" => "Lovelace",
            "password" => "valid_password",
            "password_confirmation" => "valid_password"
          }
        )

      render_submit(form)
      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == ~p"/workspaces/course_author"
      assert Oli.Accounts.get_author_by_email(email).email_confirmed_at
      Swoosh.TestAssertions.assert_no_email_sent()
    end
  end
end
