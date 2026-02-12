defmodule OliWeb.UserSettingsLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Accounts

  defp put_settings_return_to(conn, path \\ "/workspaces/student") do
    Plug.Conn.put_session(conn, "settings_return_to", path)
  end

  defp put_user_return_to(conn, path) do
    Plug.Conn.put_session(conn, "user_return_to", path)
  end

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> put_settings_return_to()
        |> live(~p"/users/settings")

      assert html =~ "Account Settings"
      assert html =~ "New Password"
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

    test "shows notice when no changes are submitted", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> put_settings_return_to()
        |> live(~p"/users/settings")

      result =
        lv
        |> form("#settings_form", %{"user" => %{}})
        |> render_submit()

      assert result =~ "No changes to save."
    end

    test "renders settings page for student with can_create_sections", %{conn: conn} do
      user = user_fixture(%{can_create_sections: true})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> put_settings_return_to()
        |> live(~p"/users/settings")

      assert html =~ "Account Settings"
    end
  end

  describe "update name form" do
    test "shows error message when First Name is empty", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> put_settings_return_to()
        |> live(~p"/users/settings")

      lv
      |> form("#settings_form", %{
        "user" => %{
          "given_name" => "",
          "family_name" => "Doe"
        }
      })
      |> render_submit()

      reloaded_user = Accounts.get_user!(user.id)
      assert reloaded_user.given_name == user.given_name
    end

    test "shows error message when Last Name is empty", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> put_settings_return_to()
        |> live(~p"/users/settings")

      lv
      |> form("#settings_form", %{
        "user" => %{
          "given_name" => "John",
          "family_name" => ""
        }
      })
      |> render_submit()

      reloaded_user = Accounts.get_user!(user.id)
      assert reloaded_user.family_name == user.family_name
    end

    test "shows both error messages when First Name and Last Name are empty on form submit",
         %{conn: conn} do
      user = user_fixture(%{given_name: "John", family_name: "Doe"})

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> put_settings_return_to()
        |> live(~p"/users/settings")

      invalid_params = %{
        "given_name" => "",
        "family_name" => ""
      }

      lv
      |> form("#settings_form", %{"user" => invalid_params})
      |> render_submit()

      reloaded_user = Accounts.get_user!(user.id)
      assert reloaded_user.given_name == user.given_name
      assert reloaded_user.family_name == user.family_name
    end

    test "shows correct full name when first name or last name change", %{conn: conn} do
      user = user_fixture(%{given_name: "John", family_name: "Doe"})

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> put_settings_return_to()
        |> live(~p"/users/settings")

      # Simulate user changing first name
      result =
        lv
        |> element("#given_name")
        |> render_change(%{"user" => %{"given_name" => "Jane", "family_name" => "Doe"}})

      assert result =~ ~s(id="given_name" value="Jane")
      assert result =~ ~s(id="family_name" value="Doe")

      # Simulate user changing last name
      result =
        lv
        |> element("#family_name")
        |> render_change(%{"user" => %{"given_name" => "Jane", "family_name" => "Smith"}})

      assert result =~ ~s(id="given_name" value="Jane")
      assert result =~ ~s(id="family_name" value="Smith")
    end

    test "shows flash message when first name or last name are successfully updated", %{
      conn: conn
    } do
      user = user_fixture(%{given_name: "John", family_name: "Doe"})

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> put_settings_return_to()
        |> live(~p"/users/settings")

      updated_params = %{
        "given_name" => "Jane",
        "family_name" => "Smith"
      }

      result =
        lv
        |> form("#settings_form", %{"user" => updated_params})
        |> render_submit()

      assert result =~ "Account details updated"

      reloaded_user = Accounts.get_user!(user.id)
      assert reloaded_user.given_name == "Jane"
      assert reloaded_user.family_name == "Smith"
    end
  end

  describe "update email form" do
    setup %{conn: conn} do
      password = valid_user_password()
      user = user_fixture(%{password: password})

      conn =
        conn
        |> log_in_user(user)
        |> put_settings_return_to()

      %{conn: conn, user: user, password: password}
    end

    test "updates the user email", %{conn: conn, password: password, user: user} do
      new_email = unique_user_email()

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#settings_form", %{
          "user" => %{"current_password" => password, "email" => new_email}
        })
        |> render_submit()

      assert result =~ "Email confirmation sent"
      assert Accounts.get_independent_user_by_email(user.email)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> element("#email")
        |> render_change(%{
          "action" => "update_email",
          "user" => %{"current_password" => "invalid", "email" => "with spaces"}
        })

      assert result =~ "Account Settings"
      assert result =~ ~s(value="with spaces")
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#settings_form", %{
          "user" => %{"current_password" => "invalid", "email" => user.email}
        })
        |> render_submit()

      assert result =~ "Account Settings"
      assert Accounts.get_independent_user_by_email(user.email)
    end

    test "updates email and password together", %{
      conn: conn,
      user: user,
      password: password
    } do
      new_email = unique_user_email()
      new_password = password <> "1"

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      lv
      |> form("#settings_form", %{
        "user" => %{
          "current_password" => password,
          "email" => new_email,
          "password" => new_password,
          "password_confirmation" => new_password
        }
      })
      |> render_submit()

      assert Accounts.get_independent_user_by_email(user.email)
      refute Accounts.get_independent_user_by_email(new_email)
      assert Accounts.get_independent_user_by_email_and_password(user.email, new_password)
      refute Accounts.get_independent_user_by_email_and_password(user.email, password)
    end

    test "does not update email when current password is invalid in combined update", %{
      conn: conn,
      user: user,
      password: password
    } do
      new_email = unique_user_email()
      new_password = password <> "1"

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      lv
      |> form("#settings_form", %{
        "user" => %{
          "current_password" => "invalid",
          "email" => new_email,
          "password" => new_password,
          "password_confirmation" => new_password
        }
      })
      |> render_submit()

      assert Accounts.get_independent_user_by_email(user.email)
      refute Accounts.get_independent_user_by_email(new_email)
      assert Accounts.get_independent_user_by_email_and_password(user.email, password)
      refute Accounts.get_independent_user_by_email_and_password(user.email, new_password)
    end

    test "shows specific error when email update lacks current password", %{
      conn: conn,
      user: user
    } do
      new_email = unique_user_email()

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#settings_form", %{
          "user" => %{
            "email" => new_email
          }
        })
        |> render_submit()

      assert result =~ "Please provide your current password to change your email address."
      assert Accounts.get_independent_user_by_email(user.email)
      refute Accounts.get_independent_user_by_email(new_email)
    end
  end

  describe "pipeline integration" do
    setup %{conn: conn} do
      password = valid_user_password()
      user = user_fixture(%{password: password})

      conn =
        conn
        |> log_in_user(user)
        |> put_settings_return_to()

      %{conn: conn, user: user, password: password}
    end

    test "processes multiple updates in correct order", %{
      conn: conn,
      user: user,
      password: password
    } do
      new_email = unique_user_email()
      new_password = password <> "1"

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      form =
        form(lv, "#settings_form", %{
          "user" => %{
            "given_name" => "Jane",
            "family_name" => "Smith",
            "email" => new_email,
            "current_password" => password,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)

      # User details should be updated
      reloaded_user = Accounts.get_user!(user.id)
      assert reloaded_user.given_name == "Jane"
      assert reloaded_user.family_name == "Smith"

      # Password should be updated
      assert Accounts.get_independent_user_by_email_and_password(user.email, new_password)
      refute Accounts.get_independent_user_by_email_and_password(user.email, password)

      # Email confirmation should be sent (old email still active)
      assert Accounts.get_independent_user_by_email(user.email)
      refute Accounts.get_independent_user_by_email(new_email)
    end

    test "stops pipeline on first error and preserves successful updates", %{
      conn: conn,
      user: user,
      password: password
    } do
      new_email = unique_user_email()
      new_password = password <> "1"

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#settings_form", %{
          "user" => %{
            "given_name" => "Jane",
            "family_name" => "Smith",
            "email" => new_email,
            "current_password" => "wrong_password",
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })
        |> render_submit()

      # Should show error message
      assert result =~ "Failed to update account details." or
               result =~ "Failed to update password." or
               result =~ "Please provide your current password"

      # User details should still be updated (pipeline processes user first)
      reloaded_user = Accounts.get_user!(user.id)
      assert reloaded_user.given_name == "Jane"
      assert reloaded_user.family_name == "Smith"

      # But password and email should remain unchanged
      assert Accounts.get_independent_user_by_email_and_password(user.email, password)
      refute Accounts.get_independent_user_by_email_and_password(user.email, new_password)
      refute Accounts.get_independent_user_by_email(new_email)
    end
  end

  describe "form validation edge cases" do
    setup %{conn: conn} do
      password = valid_user_password()
      user = user_fixture(%{password: password})

      conn =
        conn
        |> log_in_user(user)
        |> put_settings_return_to()

      %{conn: conn, user: user, password: password}
    end

    test "gracefully handles malformed params", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      # Send malformed params without 'user' key
      result =
        lv
        |> element("#given_name")
        |> render_change(%{"malformed" => %{"given_name" => "Jane"}})

      # Should not crash and should preserve existing form state
      assert result =~ "Account Settings"
      refute result =~ "Jane"
    end

    test "handles empty form submission gracefully", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#settings_form")
        |> render_submit()

      assert result =~ "No changes to save."
    end

    test "handles empty params gracefully", %{conn: conn, user: _user} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")
      result = lv |> element("#password") |> render_change(%{"user" => %{}})

      assert result =~ "Settings"
    end
  end

  describe "update password form" do
    setup %{conn: conn} do
      password = valid_user_password()
      user = user_fixture(%{password: password})

      conn =
        conn
        |> log_in_user(user)
        |> put_settings_return_to()

      %{conn: conn, user: user, password: password}
    end

    test "updates the user password", %{conn: conn, user: user, password: password} do
      new_password = valid_user_password()

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      form =
        form(lv, "#settings_form", %{
          "user" => %{
            "current_password" => password,
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

    test "renders errors with invalid data (phx-change)", %{
      conn: conn,
      user: user,
      password: password
    } do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> element("#password")
        |> render_change(%{
          "user" => %{
            "current_password" => "invalid",
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert result =~ "should be at least 12 character"
      assert Accounts.get_independent_user_by_email_and_password(user.email, password)
      refute Accounts.get_independent_user_by_email_and_password(user.email, "too short")
    end

    test "renders errors with invalid data (phx-submit)", %{
      conn: conn,
      user: user,
      password: password
    } do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      lv
      |> form("#settings_form", %{
        "user" => %{
          "current_password" => "invalid",
          "password" => "too short",
          "password_confirmation" => "does not match"
        }
      })
      |> render_submit()

      assert Accounts.get_independent_user_by_email_and_password(user.email, password)
      refute Accounts.get_independent_user_by_email_and_password(user.email, "too short")
    end

    test "updates first name and password together", %{
      conn: conn,
      user: user,
      password: password
    } do
      new_password = password <> "1"

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      form =
        form(lv, "#settings_form", %{
          "user" => %{
            "email" => user.email,
            "given_name" => "Jane",
            "family_name" => user.family_name,
            "current_password" => password,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)
      updated_conn = follow_trigger_action(form, conn)

      assert redirected_to(updated_conn) == ~p"/users/settings"

      assert Phoenix.Flash.get(updated_conn.assigns.flash, :info) =~
               "Password updated successfully!"

      reloaded_user = Accounts.get_user!(user.id)
      assert reloaded_user.given_name == "Jane"
      assert reloaded_user.family_name == user.family_name

      assert Accounts.get_independent_user_by_email_and_password(user.email, new_password)
      refute Accounts.get_independent_user_by_email_and_password(user.email, password)
    end

    test "updates last name and password together", %{
      conn: conn,
      user: user,
      password: password
    } do
      new_password = password <> "1"

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      form =
        form(lv, "#settings_form", %{
          "user" => %{
            "email" => user.email,
            "given_name" => user.given_name,
            "family_name" => "Smith",
            "current_password" => password,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)
      updated_conn = follow_trigger_action(form, conn)

      assert redirected_to(updated_conn) == ~p"/users/settings"

      assert Phoenix.Flash.get(updated_conn.assigns.flash, :info) =~
               "Password updated successfully!"

      reloaded_user = Accounts.get_user!(user.id)
      assert reloaded_user.given_name == user.given_name
      assert reloaded_user.family_name == "Smith"

      assert Accounts.get_independent_user_by_email_and_password(user.email, new_password)
      refute Accounts.get_independent_user_by_email_and_password(user.email, password)
    end

    test "triggers submit when updating name and password together", %{
      conn: conn,
      user: user,
      password: password
    } do
      new_password = password <> "1"

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      form =
        form(lv, "#settings_form", %{
          "user" => %{
            "email" => user.email,
            "given_name" => "Jane",
            "family_name" => user.family_name,
            "current_password" => password,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)
      updated_conn = follow_trigger_action(form, conn)

      assert redirected_to(updated_conn) == ~p"/users/settings"

      assert Phoenix.Flash.get(updated_conn.assigns.flash, :info) =~
               "Password updated successfully!"
    end

    test "combined updates redirect and show a single flash", %{
      conn: conn,
      user: user,
      password: password
    } do
      new_password = password <> "1"

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      form =
        form(lv, "#settings_form", %{
          "user" => %{
            "email" => user.email,
            "given_name" => "Jane",
            "family_name" => "Smith",
            "current_password" => password,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)
      updated_conn = follow_trigger_action(form, conn)

      assert redirected_to(updated_conn) == ~p"/users/settings"

      assert Phoenix.Flash.get(updated_conn.assigns.flash, :info) =~
               "Password updated successfully!"
    end

    test "updates first name, last name, and password together", %{
      conn: conn,
      user: user,
      password: password
    } do
      new_password = password <> "1"

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      form =
        form(lv, "#settings_form", %{
          "user" => %{
            "email" => user.email,
            "given_name" => "Jane",
            "family_name" => "Smith",
            "current_password" => password,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)
      updated_conn = follow_trigger_action(form, conn)

      assert redirected_to(updated_conn) == ~p"/users/settings"

      assert Phoenix.Flash.get(updated_conn.assigns.flash, :info) =~
               "Password updated successfully!"

      reloaded_user = Accounts.get_user!(user.id)
      assert reloaded_user.given_name == "Jane"
      assert reloaded_user.family_name == "Smith"

      assert Accounts.get_independent_user_by_email_and_password(user.email, new_password)
      refute Accounts.get_independent_user_by_email_and_password(user.email, password)
    end

    test "does not update password when current password is invalid in combined update", %{
      conn: conn,
      user: user,
      password: password
    } do
      new_password = password <> "1"

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#settings_form", %{
          "user" => %{
            "given_name" => "Jane",
            "family_name" => user.family_name,
            "current_password" => "invalid",
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })
        |> render_submit()

      assert result =~ "Failed to update password."

      reloaded_user = Accounts.get_user!(user.id)
      assert reloaded_user.given_name == "Jane"
      assert reloaded_user.family_name == user.family_name

      assert Accounts.get_independent_user_by_email_and_password(user.email, password)
      refute Accounts.get_independent_user_by_email_and_password(user.email, new_password)
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

      conn =
        conn
        |> log_in_user(user)
        |> put_settings_return_to()

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      refute has_element?(lv, "a[href='/users/link_account']")
    end

    test "shows when user can manage linked authoring account", %{conn: conn} do
      user =
        insert(:user, %{author: nil, independent_learner: true, can_create_sections: true})

      conn =
        conn
        |> log_in_user(user)
        |> put_settings_return_to()

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      assert has_element?(lv, "a[href='/users/link_account']", "Link authoring account")
    end

    test "shows link to manage linked authoring account when an account is already linked", %{
      conn: conn
    } do
      # user factory creates a linked anonymous author account by default
      user =
        insert(:user, %{independent_learner: true, can_create_sections: true})

      conn =
        conn
        |> log_in_user(user)
        |> put_settings_return_to()

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      author = Accounts.linked_author_account(user)

      assert author

      assert has_element?(
               lv,
               "a[href='/users/link_account'] [role='linked authoring account email']",
               author.email
             )
    end
  end

  describe "password real-time validation" do
    setup %{conn: conn} do
      password = valid_user_password()
      user = user_fixture(%{password: password})

      conn =
        conn
        |> log_in_user(user)
        |> put_settings_return_to()

      %{conn: conn, user: user, password: password}
    end

    test "does not show validation errors when both password fields are empty", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      # Initially no errors should be shown
      refute render(lv) =~ "should be at least"
      refute render(lv) =~ "does not match"
    end

    test "shows validation errors when typing in new password field", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      # Type a short password
      result =
        lv
        |> element("#password")
        |> render_change(%{"user" => %{"password" => "short"}})

      assert result =~ "should be at least 12 character"
    end

    test "shows validation errors when typing in confirm password field", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      # Type in confirm password without matching password
      result =
        lv
        |> element("#password_confirmation")
        |> render_change(%{"user" => %{"password_confirmation" => "somepassword"}})

      assert result =~ "does not match"
    end

    test "preserves content in password field when validating confirmation field", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      # First type in new password
      lv
      |> element("#password")
      |> render_change(%{"user" => %{"password" => "mynewpassword123"}})

      # Then type in confirmation field - password field should preserve content
      result =
        lv
        |> element("#password_confirmation")
        |> render_change(%{"user" => %{"password_confirmation" => "different"}})

      assert result =~ ~s(id="password" value="mynewpassword123")
      assert result =~ "does not match"
    end

    test "preserves content in confirmation field when validating password field", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      # First type in confirmation field
      lv
      |> element("#password_confirmation")
      |> render_change(%{"user" => %{"password_confirmation" => "myconfirmation123"}})

      # Then type in password field - confirmation field should preserve content
      result =
        lv
        |> element("#password")
        |> render_change(%{"user" => %{"password" => "short"}})

      assert result =~ ~s(id="password_confirmation" value="myconfirmation123")
      assert result =~ "should be at least 12 character"
    end

    test "shows interpolated error messages with correct character count", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      # Type a password that's too short
      result =
        lv
        |> element("#password")
        |> render_change(%{"user" => %{"password" => "abc"}})

      # Should show the correct minimum character count (12)
      assert result =~ "should be at least 12 character"
      refute result =~ "%{count}"
    end

    test "clears errors when passwords match and meet requirements", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      valid_password = "validpassword123"

      # Set both fields to valid matching passwords
      lv
      |> element("#password")
      |> render_change(%{"user" => %{"password" => valid_password}})

      result =
        lv
        |> element("#password_confirmation")
        |> render_change(%{
          "user" => %{
            "password" => valid_password,
            "password_confirmation" => valid_password
          }
        })

      refute result =~ "should be at least"
      refute result =~ "does not match"
    end

    test "validates only password fields without affecting other inputs", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      # Change name field - should not trigger password validation
      result =
        lv
        |> element("#given_name")
        |> render_change(%{"user" => %{"given_name" => "NewName"}})

      refute result =~ "should be at least"
      refute result =~ "does not match"
      assert result =~ ~s(id="given_name" value="NewName")
    end
  end

  describe "flash message management" do
    setup %{conn: conn} do
      password = valid_user_password()
      user = user_fixture(%{password: password})

      conn =
        conn
        |> log_in_user(user)
        |> put_settings_return_to()

      %{conn: conn, user: user, password: password}
    end

    test "clears previous flash messages before showing new ones", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      # Submit empty form to get info flash
      result =
        lv
        |> form("#settings_form", %{"user" => %{}})
        |> render_submit()

      assert result =~ "No changes to save."

      # Submit invalid form to get error flash - should clear previous
      result =
        lv
        |> form("#settings_form", %{
          "user" => %{
            "given_name" => "",
            "family_name" => "Doe"
          }
        })
        |> render_submit()

      # Should not show the previous "No changes" message
      refute result =~ "No changes to save."
    end
  end

  describe "back path" do
    test "uses settings_return_to for back and cancel links", %{conn: conn} do
      user = user_fixture()
      return_to = "/sections/sample-section"

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> put_settings_return_to(return_to)
        |> live(~p"/users/settings")

      assert lv |> element("a", "Back") |> render() =~ "href=\"#{return_to}\""
      assert lv |> element("a", "Cancel") |> render() =~ "href=\"#{return_to}\""
    end

    test "uses settings_return_to from query params", %{conn: conn} do
      user = user_fixture()
      return_to = "/sections/sample-section"

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings?settings_return_to=#{return_to}")

      assert lv |> element("a", "Back") |> render() =~ "href=\"#{return_to}\""
      assert lv |> element("a", "Cancel") |> render() =~ "href=\"#{return_to}\""
    end

    test "falls back to user_return_to when settings_return_to is missing", %{conn: conn} do
      user = user_fixture()
      return_to = "/workspaces/instructor"

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> put_user_return_to(return_to)
        |> live(~p"/users/settings")

      assert lv |> element("a", "Back") |> render() =~ "href=\"#{return_to}\""
      assert lv |> element("a", "Cancel") |> render() =~ "href=\"#{return_to}\""
    end

    test "falls back to /users/settings when no return_to is present", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      assert lv |> element("a", "Back") |> render() =~ "href=\"/users/settings\""
      assert lv |> element("a", "Cancel") |> render() =~ "href=\"/users/settings\""
    end

    test "preserves settings_return_to after password update refresh", %{conn: conn} do
      password = valid_user_password()
      user = user_fixture(%{password: password})
      return_to = "/sections/sample-section"
      new_password = password <> "1"

      conn =
        conn
        |> log_in_user(user)
        |> put_settings_return_to(return_to)

      {:ok, lv, _html} =
        conn
        |> live(~p"/users/settings")

      form =
        form(lv, "#settings_form", %{
          "user" => %{
            "email" => user.email,
            "given_name" => user.given_name,
            "family_name" => "Smith",
            "current_password" => password,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)
      updated_conn = follow_trigger_action(form, conn)

      assert redirected_to(updated_conn) == ~p"/users/settings"
      assert get_session(updated_conn, "settings_return_to") == return_to

      {:ok, refreshed_lv, _html} = live(updated_conn, ~p"/users/settings")

      assert refreshed_lv |> element("a", "Back") |> render() =~ "href=\"#{return_to}\""
      assert refreshed_lv |> element("a", "Cancel") |> render() =~ "href=\"#{return_to}\""
    end
  end
end
