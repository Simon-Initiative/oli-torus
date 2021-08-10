defmodule OliWeb.CollaboratorControllerTest do
  use OliWeb.ConnCase

  import ExUnit.CaptureLog

  alias Oli.Accounts

  @admin_email System.get_env("ADMIN_EMAIL", "admin@example.edu")
  @invalid_email "hey@example.com"
  @invite_email "invite@example.com"
  setup [:author_project_conn]

  describe "create" do
    test "redirects to project path when data is valid", %{conn: conn, project: project} do
      expect_recaptcha_http_post()

      conn =
        post(conn, Routes.collaborator_path(conn, :create, project),
          collaborator_emails: @admin_email,
          "g-recaptcha-response": "any"
        )

      assert html_response(conn, 302) =~ "/project/"
      assert assert get_flash(conn, :info) == "Collaborator invitations sent!"
    end

    test "allows multiple comma separated values", %{conn: conn, project: project} do
      expect_recaptcha_http_post()

      conn =
        post(conn, Routes.collaborator_path(conn, :create, project),
          collaborator_emails: "#{@admin_email}, #{@invite_email},someotheremail@example.edu",
          "g-recaptcha-response": "any"
        )

      assert html_response(conn, 302) =~ "/project/"
      assert assert get_flash(conn, :info) == "Collaborator invitations sent!"
    end

    test "some emails succeed, some fail", %{conn: conn, project: project} do
      expect_recaptcha_http_post()

      assert capture_log(fn ->
               conn =
                 post(conn, Routes.collaborator_path(conn, :create, project),
                   collaborator_emails: "#{@admin_email}, notevenan_email",
                   "g-recaptcha-response": "any"
                 )

               assert html_response(conn, 302) =~ "/project/"

               assert assert get_flash(conn, :error) ==
                               "Failed to add some collaborators: notevenan_email"
             end) =~ "Failed to add collaborators: notevenan_email"
    end

    test "redirects to project path when data is invalid", %{conn: conn, project: project} do
      expect_recaptcha_http_post()

      conn =
        post(conn, Routes.collaborator_path(conn, :create, project),
          collaborator_emails: @invalid_email,
          "g-recaptcha-response": "any"
        )

      assert html_response(conn, 302) =~ "/project/"
    end
  end

  describe "collaboration_invite" do
    test "accept new collaboration invitation", %{conn: conn, project: project} do
      expect_recaptcha_http_post()

      conn =
        post(conn, Routes.collaborator_path(conn, :create, project),
          collaborator_emails: @invite_email,
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
  end

  describe "delete" do
    test "redirects to project path when data is valid", %{conn: conn, project: project} do
      Oli.Authoring.Collaborators.add_collaborator(@admin_email, project.slug)
      conn = delete(conn, Routes.collaborator_path(conn, :delete, project, @admin_email))
      assert html_response(conn, 302) =~ "/project/"
    end

    test "redirects to project path when data is invalid", %{conn: conn, project: project} do
      conn = delete(conn, Routes.collaborator_path(conn, :delete, project, @invalid_email))
      assert html_response(conn, 302) =~ "/project/"
    end
  end
end
