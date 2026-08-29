defmodule OliWeb.AuthorRegistrationLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  alias Oli.Accounts
  alias Oli.Utils.Seeder.AccountsFixtures

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
    test "creates an author through the configured recaptcha implementation", %{conn: conn} do
      Oli.TestHelpers.stub_recaptcha()

      {:ok, lv, _html} = live(conn, ~p"/authors/register")

      email = AccountsFixtures.unique_author_email()

      form =
        form(lv, "#registration_form",
          author: %{
            "email" => email,
            "given_name" => "Andrew",
            "family_name" => "Carnegie",
            "password" => "valid_password",
            "password_confirmation" => "valid_password"
          }
        )

      render_submit(form)
      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == ~p"/workspaces/course_author"
      assert Accounts.get_author_by_email(email)
    end
  end
end
