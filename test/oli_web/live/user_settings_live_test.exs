defmodule OliWeb.UserSettingsLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Accounts

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/settings")

      assert html =~ "Change Email"
      assert html =~ "Change Password"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/users/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log_in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "disallow LMS users access to settings page", %{conn: conn} do
      assert {:error, redirect} =
               conn
               |> log_in_user(user_fixture(%{independent_learner: false}))
               |> live(~p"/users/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/workspaces/student"
      assert %{"error" => "You must be an independent learner to access this page."} = flash
    end
  end

  describe "update name form" do
    test "shows error message when First Name is empty", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      result =
        lv
        |> element("#user_form")
        |> render_change(%{
          "user" => %{
            "given_name" => "",
            "family_name" => "Doe"
          }
        })

      assert result =~ "Please enter a First Name."
    end

    test "shows error message when Last Name is less than two characters", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      result =
        lv
        |> element("#user_form")
        |> render_change(%{
          "user" => %{
            "given_name" => "John",
            "family_name" => "D"
          }
        })

      assert result =~ "Please enter a Last Name that is at least two characters long."
    end

    test "shows both error messages when First Name is empty and Last Name has less than 2 characters on form submit",
         %{conn: conn} do
      user = user_fixture(%{given_name: "John", family_name: "Doe"})

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      invalid_params = %{
        "given_name" => "",
        "family_name" => "A"
      }

      result =
        lv
        |> form("#user_form", %{"user" => invalid_params})
        |> render_submit()

      assert result =~ "Please enter a First Name."
      assert result =~ "Please enter a Last Name that is at least two characters long."
    end

    test "shows correct full name when first name or last name change", %{conn: conn} do
      user = user_fixture(%{given_name: "John", family_name: "Doe"})

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      # Simulate user changing first name
      result =
        lv
        |> element("#user_form")
        |> render_change(%{"user" => %{"given_name" => "Jane", "family_name" => "Doe"}})

      assert result =~ "Full name"
      assert result =~ "Jane Doe"

      # Simulate user changing last name
      result =
        lv
        |> element("#user_form")
        |> render_change(%{"user" => %{"given_name" => "Jane", "family_name" => "Smith"}})

      assert result =~ "Full name"
      assert result =~ "Jane Smith"
    end

    test "shows flash message when first name or last name are successfully updated", %{
      conn: conn
    } do
      user = user_fixture(%{given_name: "John", family_name: "Doe"})

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      updated_params = %{
        "given_name" => "Jane",
        "family_name" => "Smith"
      }

      result =
        lv
        |> form("#user_form", %{"user" => updated_params})
        |> render_submit()

      assert result =~ "Account details successfully updated."
    end
  end

  describe "update email form" do
    setup %{conn: conn} do
      password = valid_user_password()
      user = user_fixture(%{password: password})
      %{conn: log_in_user(conn, user), user: user, password: password}
    end

    test "updates the user email", %{conn: conn, password: password, user: user} do
      new_email = unique_user_email()

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => password,
          "user" => %{"email" => new_email}
        })
        |> render_submit()

      assert result =~ "A link to confirm your email"
      assert Accounts.get_independent_user_by_email(user.email)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "action" => "update_email",
          "current_password" => "invalid",
          "user" => %{"email" => "with spaces"}
        })

      assert result =~ "Change Email"
      assert result =~ "must be a valid email address"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => "invalid",
          "user" => %{"email" => user.email}
        })
        |> render_submit()

      assert result =~ "Change Email"
      assert result =~ "did not change"
      assert result =~ "is not valid"
    end
  end

  describe "update password form" do
    setup %{conn: conn} do
      password = valid_user_password()
      user = user_fixture(%{password: password})
      %{conn: log_in_user(conn, user), user: user, password: password}
    end

    test "updates the user password", %{conn: conn, user: user, password: password} do
      new_password = valid_user_password()

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      form =
        form(lv, "#password_form", %{
          "current_password" => password,
          "user" => %{
            "email" => user.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)

      new_password_conn = follow_trigger_action(form, conn)

      assert redirected_to(new_password_conn) == ~p"/users/settings"

      assert get_session(new_password_conn, :user_token) != get_session(conn, :user_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Accounts.get_independent_user_by_email_and_password(user.email, new_password)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> element("#password_form")
        |> render_change(%{
          "current_password" => "invalid",
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert result =~ "Change Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#password_form", %{
          "current_password" => "invalid",
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })
        |> render_submit()

      assert result =~ "Change Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
      assert result =~ "is not valid"
    end
  end

  describe "confirm email" do
    setup %{conn: conn} do
      user = user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{conn: log_in_user(conn, user), token: token, email: email, user: user}
    end

    test "updates the user email once", %{conn: conn, user: user, token: token, email: email} do
      {:error, redirect} = live(conn, ~p"/users/settings/confirm_email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      refute Accounts.get_independent_user_by_email(user.email)
      assert Accounts.get_independent_user_by_email(email)

      # use confirm token again
      {:error, redirect} = live(conn, ~p"/users/settings/confirm_email/#{token}")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn, user: user} do
      {:error, redirect} = live(conn, ~p"/users/settings/confirm_email/oops")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      assert Accounts.get_independent_user_by_email(user.email)
    end

    test "redirects if user is not logged in", %{token: token} do
      conn = build_conn()
      {:error, redirect} = live(conn, ~p"/users/settings/confirm_email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log_in"
      assert %{"error" => message} = flash
      assert message == "You must log in to access this page."
    end
  end

  describe "manage linked author account" do
    test "doesn't show when user can't manage linked authoring account", %{conn: conn} do
      user =
        insert(:user, %{independent_learner: true, can_create_sections: false})

      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      refute lv |> element("#link-account") |> render() =~
               "Linked Authoring Account"
    end

    test "shows when user can manage linked authoring account", %{conn: conn} do
      user =
        insert(:user, %{author: nil, independent_learner: true, can_create_sections: true})

      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      assert lv |> element("#link-account") |> render() =~
               "Linked Authoring Account"

      assert lv |> element("#link-account a[href='/users/link_account']") |> render() =~
               "Link authoring account"
    end

    test "shows link to manage linked authoring account when an account is already linked", %{
      conn: conn
    } do
      # user factory creates a linked anonymous author account by default
      user =
        insert(:user, %{independent_learner: true, can_create_sections: true})

      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      assert lv |> element("#link-account a[href='/users/link_account']") |> render() =~
               "Manage linked account"
    end
  end
end
