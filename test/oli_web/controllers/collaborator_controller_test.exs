defmodule OliWeb.CollaboratorControllerTest do
  use OliWeb.ConnCase

  alias Oli.Accounts

  @admin_email System.get_env("ADMIN_EMAIL", "admin@example.edu")
  @invalid_email "hey@example.com"
  @invite_email "invite@example.com"
  setup [:author_project_conn]

  describe "create" do
    test "redirects to project path when data is valid", %{conn: conn, project: project} do
      conn = post(conn, Routes.collaborator_path(conn, :create, project), email: @admin_email, "g-recaptcha-response": "any")
      assert html_response(conn, 302) =~ "/project/"
    end

    test "redirects to project path when data is invalid", %{conn: conn, project: project} do
      conn = post(conn, Routes.collaborator_path(conn, :create, project), email: @invalid_email, "g-recaptcha-response": "any")
      assert html_response(conn, 302) =~ "/project/"
    end
  end

  describe "accept_invite" do
    test "accept new author invitation", %{conn: conn, project: project} do
      conn = post(conn, Routes.collaborator_path(conn, :create, project), email: @invite_email, "g-recaptcha-response": "any")
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
