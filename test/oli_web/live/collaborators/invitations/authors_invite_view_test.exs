defmodule OliWeb.Collaborators.Invitations.AuthorsInviteViewTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Accounts
  alias Oli.Authoring.Course

  def create_project_and_author(%{conn: conn}) do
    %{conn: conn, project: insert(:project), author: insert(:author)}
  end

  defp authors_invite_url(token), do: ~p"/collaborators/invite/#{token}"

  defp non_existing_author() do
    # non existing authors are inserted in the DB with no password
    # (password is set by the author in the invitation redemption process)
    insert(:author, password: nil)
  end

  defp insert_invitation_token_and_author_project(
         author,
         project,
         token,
         status \\ :pending_confirmation
       ) do
    author_token =
      insert(:author_token,
        author: author,
        context: "collaborator_invitation:#{project.slug}",
        non_hashed_token: token
      )

    # encode64 token is the one sent by email to the author
    encode64_token = Base.url_encode64(token, padding: false)

    author_project =
      insert(:author_project,
        author_id: author.id,
        project_id: project.id,
        status: status,
        project_role_id: Oli.Authoring.Authors.ProjectRole.role_id().contributor
      )

    %{
      author_token: author_token,
      author_project: author_project,
      encode64_token: encode64_token
    }
  end

  describe "Authors Invite view" do
    setup [:create_project_and_author]

    test "can be accessed for a non existing token", %{conn: conn} do
      {:ok, view, _html} = live(conn, authors_invite_url("non-existing-token"))

      assert has_element?(view, "h3", "This invitation has expired or does not exist")
    end

    test "can be accessed for a rejected invitation", %{
      conn: conn,
      project: project,
      author: author
    } do
      %{encode64_token: encode64_token} =
        insert_invitation_token_and_author_project(
          author,
          project,
          "a_token_already_rejected",
          :rejected
        )

      {:ok, view, _html} = live(conn, authors_invite_url(encode64_token))

      assert has_element?(view, "h3", "This invitation has already been rejected")
    end

    test "can be accessed for a already accepted invitation", %{
      conn: conn,
      project: project,
      author: author
    } do
      %{encode64_token: encode64_token} =
        insert_invitation_token_and_author_project(
          author,
          project,
          "a_pending_invitation_token",
          :accepted
        )

      {:ok, view, _html} = live(conn, authors_invite_url(encode64_token))

      assert has_element?(view, "h3", "This invitation has already been redeemed.")

      assert has_element?(
               view,
               "a[href='/workspaces/course_author/#{project.slug}/overview']",
               "Go to project"
             )
    end

    test "can be accessed for a pending invitation", %{
      conn: conn,
      project: project,
      author: author
    } do
      %{encode64_token: encode64_token} =
        insert_invitation_token_and_author_project(
          author,
          project,
          "a_pending_invitation_token"
        )

      {:ok, view, _html} = live(conn, authors_invite_url(encode64_token))

      assert has_element?(view, "h1", "Invitation to #{project.title}")
      assert has_element?(view, "button", "Accept")
      assert has_element?(view, "button", "Reject invitation")
    end

    test "a non existing author can accept an invitation", %{conn: conn, project: project} do
      non_existing_author = non_existing_author()

      %{encode64_token: encode64_token, author_project: initial_author_project} =
        insert_invitation_token_and_author_project(
          non_existing_author,
          project,
          "a_pending_invitation_token"
        )

      assert initial_author_project.status == :pending_confirmation

      {:ok, view, _html} = live(conn, authors_invite_url(encode64_token))

      view
      |> element("button", "Accept")
      |> render_click()

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

      updated_author_project =
        Course.get_author_project(project.slug, just_created_author.id, filter_by_status: false)

      assert just_created_author.name == "Lionel Messi"
      assert just_created_author.email == non_existing_author.email
      assert just_created_author.invitation_accepted_at == ~U[2024-12-20 20:00:00Z]
      assert just_created_author.email_confirmed_at == ~U[2024-12-20 20:00:00Z]

      assert updated_author_project.status == :accepted
    end

    test "an existing author can accept an invitation", %{conn: conn, project: project} do
      existing_author = author_fixture()

      %{encode64_token: encode64_token, author_project: initial_author_project} =
        insert_invitation_token_and_author_project(
          existing_author,
          project,
          "a_pending_invitation_token"
        )

      assert initial_author_project.status == :pending_confirmation

      {:ok, view, _html} = live(conn, authors_invite_url(encode64_token))

      view
      |> element("button", "Accept")
      |> render_click()

      view
      |> element("#login_form")
      |> render_submit(%{
        "author" => %{
          "email" => existing_author.email,
          "password" => "hello world!"
        }
      })

      updated_author_project =
        Course.get_author_project(project.slug, existing_author.id, filter_by_status: false)

      assert updated_author_project.status == :accepted
    end

    test "a non existing author can reject an invitation", %{conn: conn, project: project} do
      non_existing_author = non_existing_author()

      %{encode64_token: encode64_token, author_project: initial_author_project} =
        insert_invitation_token_and_author_project(
          non_existing_author,
          project,
          "a_pending_invitation_token"
        )

      assert initial_author_project.status == :pending_confirmation

      {:ok, view, _html} = live(conn, authors_invite_url(encode64_token))

      view
      |> element("button", "Reject invitation")
      |> render_click()

      updated_author_project =
        Course.get_author_project(project.slug, non_existing_author.id, filter_by_status: false)

      assert updated_author_project.status == :rejected
    end

    test "a logged in existing author gets redirected to the project as soon as the invitation is accepted",
         %{conn: conn, project: project} do
      existing_author = author_fixture()

      conn = log_in_author(conn, existing_author)

      %{encode64_token: encode64_token, author_project: initial_author_project} =
        insert_invitation_token_and_author_project(
          existing_author,
          project,
          "a_pending_invitation_token"
        )

      assert initial_author_project.status == :pending_confirmation

      {:ok, view, _html} = live(conn, authors_invite_url(encode64_token))

      view
      |> element("button", "Accept")
      |> render_click()

      updated_author_project =
        Course.get_author_project(project.slug, existing_author.id, filter_by_status: false)

      assert updated_author_project.status == :accepted

      assert_redirect(view, ~p"/workspaces/course_author/#{project.slug}/overview")
    end

    test "a existing author needs to provide password if logged in with an account that does not match the invitation",
         %{conn: conn, project: project} do
      another_existing_account = author_fixture()
      existing_author = author_fixture()

      conn = log_in_author(conn, another_existing_account)

      %{encode64_token: encode64_token, author_project: initial_author_project} =
        insert_invitation_token_and_author_project(
          existing_author,
          project,
          "a_pending_invitation_token"
        )

      assert initial_author_project.status == :pending_confirmation

      {:ok, view, _html} = live(conn, authors_invite_url(encode64_token))

      view
      |> element("button", "Accept")
      |> render_click()

      # sees a warning that the invitation is for another account
      assert view
             |> element("p[role='account warning']")
             |> render() =~
               "<p role=\"account warning\" class=\"text-white\">\n      You are currently logged in as <strong>#{another_existing_account.email}</strong>.<br/>\n      You will be automatically logged in as <strong>#{existing_author.email}</strong>\n      to access your invitation to <strong>&quot;#{project.title}&quot;</strong>\n      Course.\n    </p>"

      # and can finish the process by providing the password
      view
      |> element("#login_form")
      |> render_submit(%{author: %{email: existing_author.email, password: "hello world!"}})

      updated_author_project =
        Course.get_author_project(project.slug, existing_author.id, filter_by_status: false)

      assert updated_author_project.status == :accepted
    end
  end
end
