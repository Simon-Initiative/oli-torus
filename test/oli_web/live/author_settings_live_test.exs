defmodule OliWeb.AuthorSettingsLiveTest do
  use OliWeb.ConnCase

  alias Oli.Accounts
  import Phoenix.LiveViewTest

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_author(author_fixture())
        |> live(~p"/authors/settings")

      assert html =~ "Change Email"
      assert html =~ "Change Password"
    end

    test "redirects if author is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/authors/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/authors/log_in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "update email form" do
    setup %{conn: conn} do
      password = valid_author_password()
      author = author_fixture(%{password: password})
      %{conn: log_in_author(conn, author), author: author, password: password}
    end

    test "updates the author email", %{conn: conn, password: password, author: author} do
      new_email = unique_author_email()

      {:ok, lv, _html} = live(conn, ~p"/authors/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => password,
          "author" => %{"email" => new_email}
        })
        |> render_submit()

      assert result =~ "A link to confirm your email"
      assert Accounts.get_author_by_email(author.email)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/authors/settings")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "action" => "update_email",
          "current_password" => "invalid",
          "author" => %{"email" => "with spaces"}
        })

      assert result =~ "Change Email"
      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, author: author} do
      {:ok, lv, _html} = live(conn, ~p"/authors/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => "invalid",
          "author" => %{"email" => author.email}
        })
        |> render_submit()

      assert result =~ "Change Email"
      assert result =~ "did not change"
      assert result =~ "is not valid"
    end
  end

  describe "update password form" do
    setup %{conn: conn} do
      password = valid_author_password()
      author = author_fixture(%{password: password})
      %{conn: log_in_author(conn, author), author: author, password: password}
    end

    test "updates the author password", %{conn: conn, author: author, password: password} do
      new_password = valid_author_password()

      {:ok, lv, _html} = live(conn, ~p"/authors/settings")

      form =
        form(lv, "#password_form", %{
          "current_password" => password,
          "author" => %{
            "email" => author.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)

      new_password_conn = follow_trigger_action(form, conn)

      assert redirected_to(new_password_conn) == ~p"/authors/settings"

      assert get_session(new_password_conn, :author_token) != get_session(conn, :author_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Accounts.get_author_by_email_and_password(author.email, new_password)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/authors/settings")

      result =
        lv
        |> element("#password_form")
        |> render_change(%{
          "current_password" => "invalid",
          "author" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert result =~ "Change Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/authors/settings")

      result =
        lv
        |> form("#password_form", %{
          "current_password" => "invalid",
          "author" => %{
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
      author = author_fixture()
      email = unique_author_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_author_update_email_instructions(
            %{author | email: email},
            author.email,
            url
          )
        end)

      %{conn: log_in_author(conn, author), token: token, email: email, author: author}
    end

    test "updates the author email once", %{
      conn: conn,
      author: author,
      token: token,
      email: email
    } do
      {:error, redirect} = live(conn, ~p"/authors/settings/confirm_email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/authors/settings"
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      refute Accounts.get_author_by_email(author.email)
      assert Accounts.get_author_by_email(email)

      # use confirm token again
      {:error, redirect} = live(conn, ~p"/authors/settings/confirm_email/#{token}")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/authors/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn, author: author} do
      {:error, redirect} = live(conn, ~p"/authors/settings/confirm_email/oops")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/authors/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      assert Accounts.get_author_by_email(author.email)
    end

    test "redirects if author is not logged in", %{token: token} do
      conn = build_conn()
      {:error, redirect} = live(conn, ~p"/authors/settings/confirm_email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/authors/log_in"
      assert %{"error" => message} = flash
      assert message == "You must log in to access this page."
    end
  end

  describe "update name form" do
    test "shows error message when First Name is empty", %{conn: conn} do
      author = author_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_author(author)
        |> live(~p"/authors/settings")

      result =
        lv
        |> element("#author_form")
        |> render_change(%{
          "author" => %{
            "given_name" => "",
            "family_name" => "Doe"
          }
        })

      assert result =~ "Please enter a First Name."
    end

    test "shows error message when Last Name is less than two characters", %{conn: conn} do
      author = author_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_author(author)
        |> live(~p"/authors/settings")

      result =
        lv
        |> element("#author_form")
        |> render_change(%{
          "author" => %{
            "given_name" => "John",
            "family_name" => "D"
          }
        })

      assert result =~ "Please enter a Last Name that is at least two characters long."
    end

    test "shows both error messages when First Name is empty and Last Name has less than 2 characters on form submit",
         %{conn: conn} do
      author = author_fixture(%{given_name: "John", family_name: "Doe"})

      {:ok, lv, _html} =
        conn
        |> log_in_author(author)
        |> live(~p"/authors/settings")

      invalid_params = %{
        "given_name" => "",
        "family_name" => "A"
      }

      result =
        lv
        |> form("#author_form", %{"author" => invalid_params})
        |> render_submit()

      assert result =~ "Please enter a First Name."
      assert result =~ "Please enter a Last Name that is at least two characters long."
    end

    test "shows correct full name when first name or last name change", %{conn: conn} do
      author = author_fixture(%{given_name: "John", family_name: "Doe"})

      {:ok, lv, _html} =
        conn
        |> log_in_author(author)
        |> live(~p"/authors/settings")

      # Simulate author changing first name
      result =
        lv
        |> element("#author_form")
        |> render_change(%{"author" => %{"given_name" => "Jane", "family_name" => "Doe"}})

      assert result =~ "Full name"
      assert result =~ "Jane Doe"

      # Simulate author changing last name
      result =
        lv
        |> element("#author_form")
        |> render_change(%{"author" => %{"given_name" => "Jane", "family_name" => "Smith"}})

      assert result =~ "Full name"
      assert result =~ "Jane Smith"
    end

    test "shows flash message when first name or last name are successfully updated", %{
      conn: conn
    } do
      author = author_fixture(%{given_name: "John", family_name: "Doe"})

      {:ok, lv, _html} =
        conn
        |> log_in_author(author)
        |> live(~p"/authors/settings")

      updated_params = %{
        "given_name" => "Jane",
        "family_name" => "Smith"
      }

      result =
        lv
        |> form("#author_form", %{"author" => updated_params})
        |> render_submit()

      assert result =~ "Account details successfully updated."
    end
  end
end
