defmodule OliWeb.AuthorLoginLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "Log in page" do
    test "renders log in page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/authors/log_in")

      assert html =~ "Sign in"
      assert html =~ "Create an account"
      assert html =~ "Forgot password?"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_author(Oli.AccountsFixtures.author_fixture())
        |> live(~p"/authors/log_in")
        |> follow_redirect(conn, "/workspaces/course_author")

      assert {:ok, _conn} = result
    end
  end

  describe "author login" do
    test "redirects if author login with valid credentials", %{conn: conn} do
      password = "123456789abcd"
      author = Oli.AccountsFixtures.author_fixture(%{password: password})

      {:ok, lv, _html} = live(conn, ~p"/authors/log_in")

      form =
        form(lv, "#login_form",
          author: %{email: author.email, password: password, remember_me: true}
        )

      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/workspaces/course_author"
    end

    test "redirects to login page with a flash error if there are no valid credentials", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/authors/log_in")

      form =
        form(lv, "#login_form",
          author: %{email: "test@email.com", password: "123456", remember_me: true}
        )

      conn = submit_form(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"

      assert redirected_to(conn) == "/authors/log_in"
    end
  end

  describe "login navigation" do
    test "redirects to registration page when the Register button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/authors/log_in")

      {:ok, conn} =
        lv
        |> element(~s|a:fl-contains("Create an account")|)
        |> render_click()
        |> follow_redirect(conn, ~p"/authors/register")

      assert html_response(conn, 200) =~ "Create account"
    end

    test "redirects to forgot password page when the Forgot Password button is clicked", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/authors/log_in")

      {:ok, conn} =
        lv
        |> element(~s|a:fl-contains("Forgot password?")|)
        |> render_click()
        |> follow_redirect(conn, ~p"/authors/reset_password")

      assert conn.resp_body =~ "Forgot your password?"
    end
  end
end
