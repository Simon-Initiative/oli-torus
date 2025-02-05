defmodule OliWeb.Authors.Invitations.InviteViewTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Accounts

  defp authors_invite_url(token), do: ~p"/authors/invite/#{token}"

  defp non_existing_author() do
    # non existing authors are inserted in the DB with no password
    # (password is set by the author in the invitation redemption process)
    insert(:author, password: nil)
  end

  defp insert_invitation_token(author, token) do
    author_token =
      insert(:author_token,
        author: author,
        context: "author_invitation",
        non_hashed_token: token
      )

    # encode64 token is the one sent by email to the author
    encode64_token = Base.url_encode64(token, padding: false)

    %{author_token: author_token, encode64_token: encode64_token}
  end

  describe "Authors Invite view" do
    test "can be accessed for a non existing token", %{conn: conn} do
      {:ok, view, _html} = live(conn, authors_invite_url("non-existing-token"))

      assert has_element?(view, "h3", "This invitation has expired or does not exist")
    end

    test "can be accessed for an existing author", %{conn: conn} do
      existing_author = author_fixture()
      %{encode64_token: encode64_token} = insert_invitation_token(existing_author, "a_token")

      {:ok, view, _html} = live(conn, authors_invite_url(encode64_token))

      assert has_element?(view, "h1", "Invitation to create an Authoring Account")
    end

    test "a non existing author can redeem an invitation", %{conn: conn} do
      non_existing_author = non_existing_author()

      %{encode64_token: encode64_token} = insert_invitation_token(non_existing_author, "a_token")

      {:ok, view, _html} = live(conn, authors_invite_url(encode64_token))

      # new author is required to register

      stub_recaptcha()
      stub_current_time(~U[2024-12-20 20:00:00Z])

      view
      |> element("#registration_form")
      |> render_change(%{
        "author" => %{
          "family_name" => "Messi",
          "given_name" => "Lionel",
          "password" => "a_valid_password",
          "password_confirmation" => "a_valid_password"
        }
      })

      view
      |> element("#registration_form")
      |> render_submit()

      just_created_author =
        Accounts.get_author_by_email_and_password(non_existing_author.email, "a_valid_password")

      assert just_created_author.name == "Lionel Messi"
      assert just_created_author.email == non_existing_author.email
      assert just_created_author.invitation_accepted_at == ~U[2024-12-20 20:00:00Z]
      assert just_created_author.email_confirmed_at == ~U[2024-12-20 20:00:00Z]
    end

    test "an existing author can redeem an invitation", %{conn: conn} do
      existing_author = author_fixture()

      %{encode64_token: encode64_token} = insert_invitation_token(existing_author, "a_token")

      {:ok, view, _html} = live(conn, authors_invite_url(encode64_token))

      view
      |> element("#login_form")
      |> render_submit(%{
        "author" => %{
          "email" => existing_author.email,
          "password" => "hello world!"
        }
      })
    end

    test "a logged in existing author gets redirected to course author workspace as soon as the invitation is accessed",
         %{conn: conn} do
      existing_author = author_fixture()

      conn = log_in_author(conn, existing_author)

      %{encode64_token: encode64_token} = insert_invitation_token(existing_author, "a_token")

      {:error, {:redirect, %{to: "/workspaces/course_author/", flash: %{}}}} =
        live(conn, authors_invite_url(encode64_token))
    end

    test "a existing author needs to provide password if logged in with an account that does not match the invitation",
         %{conn: conn} do
      another_existing_account = author_fixture()
      existing_author = author_fixture()

      conn = log_in_author(conn, another_existing_account)

      %{encode64_token: encode64_token} = insert_invitation_token(existing_author, "a_token")

      {:ok, view, _html} = live(conn, authors_invite_url(encode64_token))

      # sees a warning that the invitation is for another account
      assert view
             |> element("p[role='account warning']")
             |> render() =~
               "<p role=\"account warning\" class=\"text-white\">\n      You are currently logged in as <strong>#{another_existing_account.email}</strong>.<br/>\n      You will be automatically logged in as <strong>#{existing_author.email}</strong>\n      after you sign in.\n    </p>"

      # and can finish the process by providing the password
      view
      |> element("#login_form")
      |> render_submit(%{author: %{email: existing_author.email, password: "hello world!"}})
    end
  end
end
