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
      assert result =~ "must have the @ sign and no spaces"
      assert result =~ "should be at least 12 character"
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Sign in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/authors/register")

      {:ok, conn} =
        lv
        |> element(~s|a:fl-contains("Sign in to existing account")|)
        |> render_click()
        |> follow_redirect(conn, ~p"/authors/log_in")

      assert html_response(conn, 200) =~ "Sign in"
    end
  end
end
