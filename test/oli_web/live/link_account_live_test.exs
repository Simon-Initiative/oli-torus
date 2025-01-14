defmodule OliWeb.LinkAccountLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  describe "Link account page" do
    test "renders link account page", %{conn: conn} do
      user = insert(:user)

      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/users/link_account")

      assert html =~ "Link Authoring Account"
    end
  end

  describe "links account after author login" do
    test "redirects with valid credentials", %{conn: conn} do
      user = insert(:user)

      conn = log_in_user(conn, user)

      password = "123456789abcd"
      author = Oli.Utils.Seeder.AccountsFixtures.author_fixture(%{password: password})

      {:ok, lv, _html} = live(conn, ~p"/users/link_account")

      form =
        form(lv, "#link_account_form",
          author: %{email: author.email, password: password, link_account_user_id: "#{user.id}"}
        )

      conn = submit_form(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Your authoring account has been linked to your user account."

      assert redirected_to(conn) == ~p"/users/settings"
    end

    test "redirects back to link account page with a flash error if there are no valid credentials",
         %{
           conn: conn
         } do
      user = insert(:user)

      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/users/link_account")

      form =
        form(lv, "#link_account_form",
          author: %{
            email: "test@email.com",
            password: "123456",
            link_account_user_id: "#{user.id}"
          }
        )

      conn = submit_form(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"

      assert redirected_to(conn) == ~p"/users/link_account"
    end
  end
end
