defmodule OliWeb.InviteControllerTest do
  use OliWeb.ConnCase

  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Accounts.Author

  import Oli.Factory

  @invite_email "invite@example.com"
  setup [:create_admin]

  describe "accept_invite" do
    test "accept new author invitation", %{conn: conn} do
      expect_recaptcha_http_post()

      conn =
        post(conn, Routes.invite_path(conn, :create),
          email: @invite_email,
          "g-recaptcha-response": "any"
        )

      new_author = Accounts.get_author_by_email(@invite_email)
      token = PowInvitation.Plug.sign_invitation_token(conn, new_author)

      put(
        conn,
        Routes.pow_invitation_invitation_path(conn, :update, token),
        %{
          user: %{
            email: @invite_email,
            given_name: "me",
            family_name: "too",
            password: "passingby",
            password_confirmation: "passingby"
          }
        }
      )

      new_author = Accounts.get_author_by_email(@invite_email)
      assert new_author.given_name == "me"
      assert new_author.invitation_accepted_at
    end

    test "accept new section enrollment invitation", %{conn: conn} do
      expect_recaptcha_http_post()
      section = insert(:section)

      # Create the invitations
      conn =
        post(
          conn,
          Routes.invite_path(conn, :create_bulk, section.slug,
            emails: ["invite@example.com", "invite2@example.com"],
            role: "instructor",
            "g-recaptcha-response": "any"
          )
        )

      # Accept the invitation for the first user
      new_user = Accounts.get_user_by(email: "invite@example.com")
      token = PowInvitation.Plug.sign_invitation_token(conn, new_user)

      put(
        conn,
        Routes.delivery_pow_invitation_invitation_path(conn, :update, token),
        %{
          user: %{
            email: "invite@example.com",
            given_name: "First",
            family_name: "User",
            password: "passingby",
            password_confirmation: "passingby"
          }
        }
      )

      new_user = Accounts.get_user_by(email: "invite@example.com")
      assert new_user.given_name == "First"
      assert new_user.family_name == "User"
      assert new_user.invitation_accepted_at

      # Accept the invitation for the second user
      new_user = Accounts.get_user_by(email: "invite2@example.com")
      token = PowInvitation.Plug.sign_invitation_token(conn, new_user)

      put(
        conn,
        Routes.delivery_pow_invitation_invitation_path(conn, :update, token),
        %{
          user: %{
            email: "invite2@example.com",
            given_name: "Second",
            family_name: "User",
            password: "passingby",
            password_confirmation: "passingby"
          }
        }
      )

      new_user = Accounts.get_user_by(email: "invite2@example.com")
      assert new_user.given_name == "Second"
      assert new_user.family_name == "User"
      assert new_user.invitation_accepted_at
    end
  end

  defp create_admin(%{conn: conn}) do
    {:ok, author} =
      Author.noauth_changeset(%Author{}, %{
        email: "test@test.com",
        given_name: "First",
        family_name: "Last",
        provider: "foo",
        system_role_id: Accounts.SystemRole.role_id().admin
      })
      |> Repo.insert()

    conn =
      Pow.Plug.assign_current_user(conn, author, OliWeb.Pow.PowHelpers.get_pow_config(:author))

    {:ok, conn: conn, author: author}
  end
end
