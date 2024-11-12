defmodule OliWeb.InviteControllerTest do
  use OliWeb.ConnCase
  use Bamboo.Test

  import Oli.Factory

  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Accounts.Author

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

    test "deliver new instructor invitation", %{conn: conn} do
      expect_recaptcha_http_post()
      section = insert(:section)

      post(
        conn,
        Routes.invite_path(conn, :create_bulk, section.slug,
          emails: [@invite_email],
          role: "instructor",
          "g-recaptcha-response": "any",
          inviter: "author"
        )
      )

      assert Accounts.get_user_by(email: @invite_email)

      assert_delivered_email_matches(%{to: [{_, @invite_email}], text_body: text_body})
      assert text_body =~ "You've been added by First Last as an instructor to the following"
      assert text_body =~ "Join now"
      assert text_body =~ "/registration/new?section=#{section.slug}&from_invitation_link%3F=true"
    end

    test "deliver new student invitation", %{conn: conn} do
      expect_recaptcha_http_post()
      section = insert(:section)

      post(
        conn,
        Routes.invite_path(conn, :create_bulk, section.slug,
          emails: [@invite_email],
          role: "student",
          "g-recaptcha-response": "any",
          inviter: "author"
        )
      )

      assert Accounts.get_user_by(email: @invite_email)

      assert_delivered_email_matches(%{to: [{_, @invite_email}], text_body: text_body})
      assert text_body =~ "You've been added by First Last as a student to the following"
      assert text_body =~ "Join now"
      assert text_body =~ "/registration/new?section=#{section.slug}&from_invitation_link%3F=true"
    end

    test "deliver existing instructor invitation", %{conn: conn} do
      expect_recaptcha_http_post()
      section = insert(:section)
      insert(:user, email: @invite_email)

      post(
        conn,
        Routes.invite_path(conn, :create_bulk, section.slug,
          emails: [@invite_email],
          role: "instructor",
          "g-recaptcha-response": "any",
          inviter: "author"
        )
      )

      assert Accounts.get_user_by(email: @invite_email)

      assert_delivered_email_matches(%{to: [{_, @invite_email}], text_body: text_body})
      assert text_body =~ "You've been added by First Last as an instructor to the following"
      assert text_body =~ "Go to the course"
      assert text_body =~ "/sections/#{section.slug}?from_invitation_link%3F=true)"
    end

    test "deliver existing student invitation", %{conn: conn} do
      expect_recaptcha_http_post()
      section = insert(:section)
      insert(:user, email: @invite_email)

      post(
        conn,
        Routes.invite_path(conn, :create_bulk, section.slug,
          emails: [@invite_email],
          role: "student",
          "g-recaptcha-response": "any",
          inviter: "author"
        )
      )

      assert Accounts.get_user_by(email: @invite_email)

      assert_delivered_email_matches(%{to: [{_, @invite_email}], text_body: text_body})
      assert text_body =~ "You've been added by First Last as a student to the following"
      assert text_body =~ "Go to the course"
      assert text_body =~ "/sections/#{section.slug}?from_invitation_link%3F=true)"
    end
  end

  defp create_admin(%{conn: conn}) do
    {:ok, author} =
      Author.noauth_changeset(%Author{}, %{
        email: "test@test.com",
        given_name: "First",
        family_name: "Last",
        provider: "foo",
        system_role_id: Accounts.SystemRole.role_id().system_admin
      })
      |> Repo.insert()

    conn =
      log_in_author(conn, author)

    {:ok, conn: conn, author: author}
  end
end
