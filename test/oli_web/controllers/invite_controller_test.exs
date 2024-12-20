defmodule OliWeb.InviteControllerTest do
  use OliWeb.ConnCase
  import Swoosh.TestAssertions

  import Oli.Factory

  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Accounts.Author

  @invite_email "invite@example.com"
  setup [:create_admin]

  describe "Create invitation" do
    test "deliver new instructor invitation", %{conn: conn} do
      expect_recaptcha_http_post()
      stub_real_current_time()
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

      assert_email_sent(
        to: @invite_email,
        subject: "You were invited as an instructor to \"#{section.title}\""
      )
    end

    test "deliver new student invitation", %{conn: conn} do
      expect_recaptcha_http_post()
      stub_real_current_time()
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

      assert_email_sent(
        to: @invite_email,
        subject: "You were invited as a student to \"#{section.title}\""
      )
    end

    test "deliver existing instructor invitation", %{conn: conn} do
      expect_recaptcha_http_post()
      stub_real_current_time()
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

      assert_email_sent(
        to: @invite_email,
        subject: "You were invited as an instructor to \"#{section.title}\""
      )
    end

    test "deliver existing student invitation", %{conn: conn} do
      expect_recaptcha_http_post()
      stub_real_current_time()
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

      assert_email_sent(
        to: @invite_email,
        subject: "You were invited as a student to \"#{section.title}\""
      )
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
