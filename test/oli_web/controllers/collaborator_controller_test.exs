defmodule OliWeb.CollaboratorControllerTest do
  use OliWeb.ConnCase

  import ExUnit.CaptureLog
  import Oli.Factory

  alias Oli.Accounts
  alias Oli.Accounts.AuthorToken
  alias Oli.AssentAuth.AuthorIdentity
  alias Oli.Authoring.{Collaborators, Course}
  alias Oli.Repo

  @admin_email System.get_env("ADMIN_EMAIL", "admin@example.edu")
  @invalid_email "hey@example.com"
  @invite_email "invite@example.com"

  defp get_authors(project) do
    Accounts.authors_projects(project)
    |> Enum.map(fn author_project -> author_project.author.email end)
    |> Enum.join(", ")
  end

  setup [:author_project_conn]

  describe "create" do
    test "redirects to project path when data is valid", %{conn: conn, project: project} do
      expect_recaptcha_http_post()

      conn =
        post(conn, Routes.collaborator_path(conn, :create, project),
          collaborator_emails: @admin_email,
          authors: get_authors(project),
          "g-recaptcha-response": "any"
        )

      assert html_response(conn, 302) =~ "/workspaces/course_author/#{project.slug}/overview"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Collaborator invitations sent!"
    end

    test "allows multiple comma separated values", %{conn: conn, project: project} do
      expect_recaptcha_http_post()

      conn =
        post(conn, Routes.collaborator_path(conn, :create, project),
          collaborator_emails: "#{@admin_email}, #{@invite_email},someotheremail@example.edu",
          authors: get_authors(project),
          "g-recaptcha-response": "any"
        )

      assert html_response(conn, 302) =~ "/workspaces/course_author/#{project.slug}/overview"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Collaborator invitations sent!"
    end

    test "allows capital letters in emails", %{conn: conn, project: project} do
      expect_recaptcha_http_post()

      conn =
        post(conn, Routes.collaborator_path(conn, :create, project),
          collaborator_emails: "Invite@Example.COM",
          authors: get_authors(project),
          "g-recaptcha-response": "any"
        )

      assert html_response(conn, 302) =~ "/workspaces/course_author/#{project.slug}/overview"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Collaborator invitations sent!"
    end

    test "some emails succeed, some fail", %{conn: conn, project: project} do
      expect_recaptcha_http_post()

      assert capture_log(fn ->
               conn =
                 post(conn, Routes.collaborator_path(conn, :create, project),
                   collaborator_emails: "#{@admin_email}, notevenan_email",
                   authors: get_authors(project),
                   "g-recaptcha-response": "any"
                 )

               assert html_response(conn, 302) =~
                        "/workspaces/course_author/#{project.slug}/overview"

               assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
                        "Failed to invite some collaborators due to invalid email(s): notevenan_email"
             end) =~
               "Failed to invite some collaborators due to invalid email(s): [\"notevenan_email\"]"
    end

    test "redirects to project path when data is invalid", %{conn: conn, project: project} do
      expect_recaptcha_http_post()

      conn =
        post(conn, Routes.collaborator_path(conn, :create, project),
          collaborator_emails: @invalid_email,
          authors: get_authors(project),
          "g-recaptcha-response": "any"
        )

      assert html_response(conn, 302) =~ "/workspaces/course_author/#{project.slug}/overview"
    end

    test "shows an error message when the author's email already exists", %{
      conn: conn,
      project: project
    } do
      expect_recaptcha_http_post()

      author_email =
        project |> Oli.Repo.preload(:authors) |> Map.get(:authors) |> hd |> Map.get(:email)

      conn =
        post(conn, Routes.collaborator_path(conn, :create, project),
          collaborator_emails: author_email,
          authors: get_authors(project),
          "g-recaptcha-response": "any"
        )

      assert html_response(conn, 302) =~ "workspaces/course_author/#{project.slug}/overview"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "This person is already a collaborator in this project."
    end

    test "shows an error message if the number of invitations exceeds the allowed limit", %{
      conn: conn,
      project: project
    } do
      expect_recaptcha_http_post()

      list_of_emails =
        Enum.reduce(1..25, "", fn index, acc ->
          email = "author_#{index}@example.com"
          if acc == "", do: email, else: "#{acc}, #{email}"
        end)

      conn =
        post(conn, Routes.collaborator_path(conn, :create, project),
          collaborator_emails: list_of_emails,
          authors: get_authors(project),
          "g-recaptcha-response": "any"
        )

      assert html_response(conn, 302) =~ "/workspaces/course_author/#{project.slug}/overview"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Collaborator invitations cannot exceed 20 emails at a time. Please try again with fewer invites"
    end
  end

  describe "delete" do
    for {account_type, status} <- [
          {:google, :pending_confirmation},
          {:google, :accepted},
          {:password, :pending_confirmation},
          {:unregistered, :pending_confirmation}
        ] do
      @account_type account_type
      @status status
      test "preserves #{@account_type} accounts when removing #{@status} collaborations", %{
        conn: conn,
        project: project
      } do
        author =
          case @account_type do
            :google ->
              insert(:author,
                password_hash: nil,
                user_identities: [
                  %AuthorIdentity{uid: "collaborator-removal", provider: "google"}
                ]
              )

            :password ->
              author_fixture()

            :unregistered ->
              insert(:author, password_hash: nil)
          end

        original = insert(:project, authors: [])

        original_membership =
          insert(:author_project, author_id: author.id, project_id: original.id)

        user = insert(:user, author: author)
        session_token = Accounts.generate_author_session_token(author)
        identities = Repo.preload(author, :user_identities).user_identities

        {:ok, _} = Collaborators.do_add_collaborator(author.email, project.slug, @status)

        tokens =
          for slug <- [project.slug, project.slug, original.slug] do
            {encoded, token} =
              AuthorToken.build_email_token(author, "collaborator_invitation:#{slug}")

            Repo.insert!(token)
            encoded
          end

        conn = delete(conn, Routes.collaborator_path(conn, :delete, project, author.email))

        assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Author removed from project"
        assert Accounts.get_author_by_email(author.email).id == author.id
        assert Course.get_author_project(original.slug, author.id) == original_membership
        assert Course.get_author_project(project.slug, author.id, filter_by_status: false) == nil
        assert Repo.reload!(user).author_id == author.id
        assert Repo.preload(Repo.reload!(author), :user_identities).user_identities == identities
        assert Accounts.get_author_by_session_token(session_token).id == author.id

        [removed_token, another_removed_token, retained_token] = tokens
        assert Accounts.get_author_token_by_collaboration_invitation_token(removed_token) == nil

        assert Accounts.get_author_token_by_collaboration_invitation_token(another_removed_token) ==
                 nil

        assert Accounts.get_author_token_by_collaboration_invitation_token(retained_token)

        {:ok, reinvited} =
          Collaborators.invite_collaborator(
            "Owner",
            "owner@example.edu",
            author.email,
            project.slug
          )

        assert reinvited.author_id == author.id
      end
    end

    test "redirects to project path when data is valid", %{conn: conn, project: project} do
      Oli.Authoring.Collaborators.add_collaborator(@admin_email, project.slug)
      conn = delete(conn, Routes.collaborator_path(conn, :delete, project, @admin_email))
      assert html_response(conn, 302) =~ "/workspaces/course_author/#{project.slug}/overview"
    end

    test "redirects to project path when data is invalid", %{conn: conn, project: project} do
      conn = delete(conn, Routes.collaborator_path(conn, :delete, project, @invalid_email))
      assert html_response(conn, 302) =~ "/workspaces/course_author/#{project.slug}/overview"
    end
  end
end
