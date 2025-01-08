defmodule OliWeb.InviteControllerTest do
  use OliWeb.ConnCase
  import Swoosh.TestAssertions

  import Oli.Factory
  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Accounts.Author

  @invite_email "invite@example.com"
  setup [:create_admin]

  describe "`create_bulk` action" do
    test "for a new instructor: creates new user, enrolls user to the given section, creates invitation token and delivers email invitation",
         %{conn: conn} do
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

      # user is created
      new_user = Accounts.get_user_by(email: @invite_email)
      assert new_user

      # user is enrolled to the section as an instructor with :pending_confirmation status
      enrollment =
        Oli.Delivery.Sections.get_enrollment(section.slug, new_user.id, filter_by_status: false)
        |> Repo.preload(:context_roles)

      assert enrollment.section_id == section.id

      assert enrollment.status == :pending_confirmation

      assert hd(enrollment.context_roles).uri ==
               "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor"

      # invitation user_token is created
      context = "enrollment_invitation:#{section.slug}"

      assert from(ut in Oli.Accounts.UserToken,
               where:
                 ut.user_id == ^new_user.id and ut.context == ^context and
                   ut.sent_to == @invite_email
             )
             |> Repo.one()

      # and email is sent
      assert_email_sent(
        to: @invite_email,
        subject: "You were invited as an instructor to \"#{section.title}\""
      )
    end

    test "for a new student: creates new user, enrolls user to the given section, creates invitation token and delivers email invitation",
         %{conn: conn} do
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

      # user is created
      new_user = Accounts.get_user_by(email: @invite_email)
      assert new_user

      # user is enrolled to the section as a student with :pending_confirmation status
      enrollment =
        Oli.Delivery.Sections.get_enrollment(section.slug, new_user.id, filter_by_status: false)
        |> Repo.preload(:context_roles)

      assert enrollment.section_id == section.id

      assert enrollment.status == :pending_confirmation

      assert hd(enrollment.context_roles).uri ==
               "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"

      # invitation user_token is created
      context = "enrollment_invitation:#{section.slug}"

      assert from(ut in Oli.Accounts.UserToken,
               where:
                 ut.user_id == ^new_user.id and ut.context == ^context and
                   ut.sent_to == @invite_email
             )
             |> Repo.one()

      # and email is sent

      assert_email_sent(
        to: @invite_email,
        subject: "You were invited as a student to \"#{section.title}\""
      )
    end

    test "for an existing instructor: enrolls user to the given section, creates invitation token and delivers email invitation",
         %{conn: conn} do
      expect_recaptcha_http_post()
      stub_real_current_time()
      section = insert(:section)
      existing_instructor = user_fixture(email: @invite_email)

      post(
        conn,
        Routes.invite_path(conn, :create_bulk, section.slug,
          emails: [@invite_email],
          role: "instructor",
          "g-recaptcha-response": "any",
          inviter: "author"
        )
      )

      # user is enrolled to the section as an instructor with :pending_confirmation status
      enrollment =
        Oli.Delivery.Sections.get_enrollment(section.slug, existing_instructor.id,
          filter_by_status: false
        )
        |> Repo.preload(:context_roles)

      assert enrollment.section_id == section.id

      assert enrollment.status == :pending_confirmation

      assert hd(enrollment.context_roles).uri ==
               "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor"

      # invitation user_token is created
      context = "enrollment_invitation:#{section.slug}"

      assert from(ut in Oli.Accounts.UserToken,
               where:
                 ut.user_id == ^existing_instructor.id and ut.context == ^context and
                   ut.sent_to == @invite_email
             )
             |> Repo.one()

      # and email is sent
      assert_email_sent(
        to: @invite_email,
        subject: "You were invited as an instructor to \"#{section.title}\""
      )
    end

    test "for an existing student: enrolls user to the given section, creates invitation token and delivers email invitation",
         %{conn: conn} do
      expect_recaptcha_http_post()
      stub_real_current_time()
      section = insert(:section)
      existing_student = user_fixture(email: @invite_email)

      post(
        conn,
        Routes.invite_path(conn, :create_bulk, section.slug,
          emails: [@invite_email],
          role: "student",
          "g-recaptcha-response": "any",
          inviter: "author"
        )
      )

      # user is enrolled to the section as a student with :pending_confirmation status
      enrollment =
        Oli.Delivery.Sections.get_enrollment(section.slug, existing_student.id,
          filter_by_status: false
        )
        |> Repo.preload(:context_roles)

      assert enrollment.section_id == section.id

      assert enrollment.status == :pending_confirmation

      assert hd(enrollment.context_roles).uri ==
               "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"

      # invitation user_token is created
      context = "enrollment_invitation:#{section.slug}"

      assert from(ut in Oli.Accounts.UserToken,
               where:
                 ut.user_id == ^existing_student.id and ut.context == ^context and
                   ut.sent_to == @invite_email
             )
             |> Repo.one()

      # and email is sent

      assert_email_sent(
        to: @invite_email,
        subject: "You were invited as a student to \"#{section.title}\""
      )
    end
  end

  describe "accept_user_invitation action" do
    setup [:create_section_and_user]

    test "logs in the user and redirects to the section", %{
      conn: conn,
      section: section,
      user: user
    } do
      conn =
        post(
          conn,
          ~p"/users/accept_invitation?email=#{user.email}&section_slug=#{section.slug}",
          %{"user" => %{"password" => "hello world!", "remember_me" => "false"}}
        )

      assert conn.resp_body ==
               "<html><body>You are being <a href=\"/sections/#{section.slug}\">redirected</a>.</body></html>"
    end

    test "does not log in the user and redirects to the section if the provided password is invalid",
         %{
           conn: conn,
           section: section,
           user: user
         } do
      conn =
        post(
          conn,
          ~p"/users/accept_invitation?email=#{user.email}&section_slug=#{section.slug}",
          %{"user" => %{"password" => "invalid_password", "remember_me" => "false"}}
        )

      assert conn.private.plug_session["phoenix_flash"]["error"] == "Invalid email or password"
    end
  end

  describe "accept_collaborator_invitation action" do
    setup [:create_project_and_author]

    test "logs in the author and redirects to the project", %{
      conn: conn,
      project: project,
      author: author
    } do
      conn =
        post(
          conn,
          ~p"/collaborators/accept_invitation?email=#{author.email}&project_slug=#{project.slug}",
          %{"author" => %{"password" => "hello world!", "remember_me" => "false"}}
        )

      # update this url
      assert conn.resp_body ==
               "<html><body>You are being <a href=\"/workspaces/course_author/#{project.slug}/overview\">redirected</a>.</body></html>"
    end

    test "does not log in the author and redirects to the project if the provided password is invalid",
         %{
           conn: conn,
           project: project,
           author: author
         } do
      conn =
        post(
          conn,
          ~p"/collaborators/accept_invitation?email=#{author.email}&project_slug=#{project.slug}",
          %{"author" => %{"password" => "invalid_password", "remember_me" => "false"}}
        )

      assert conn.private.plug_session["phoenix_flash"]["error"] == "Invalid email or password"
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

  defp create_section_and_user(%{conn: conn}) do
    {:ok, conn: conn, section: insert(:section), user: user_fixture()}
  end

  defp create_project_and_author(%{conn: conn}) do
    {:ok, conn: conn, project: insert(:project), author: author_fixture()}
  end
end
