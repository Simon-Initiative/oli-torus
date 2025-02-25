defmodule OliWeb.Users.Invitations.UsersInviteViewTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Accounts
  alias Oli.Delivery.Sections
  alias Oli.AssentAuth.UserIdentity

  def create_section_and_user(%{conn: conn}) do
    %{conn: conn, section: insert(:section), user: insert(:user)}
  end

  defp users_invite_url(token), do: ~p"/users/invite/#{token}"

  defp non_existing_user() do
    # non existing users are inserted in the DB with no password
    # (password is set by the user in the invitation redemption process)
    insert(:user, password: nil)
  end

  defp social_login_user() do
      insert(:user, user_identities: [%UserIdentity{uid: "123", provider: "google"}])
  end

  defp insert_invitation_token_and_enrollment(
         user,
         section,
         token,
         role,
         status \\ :pending_confirmation
       ) do
    user_token =
      insert(:user_token,
        user: user,
        context: "enrollment_invitation:#{section.slug}",
        non_hashed_token: token
      )

    # encode64 token is the one sent by email to the user
    encode64_token = Base.url_encode64(token, padding: false)

    context_role =
      case role do
        "student" -> Lti_1p3.Tool.ContextRoles.get_role(:context_learner)
        "instructor" -> Lti_1p3.Tool.ContextRoles.get_role(:context_instructor)
      end

    {:ok, enrollment} =
      Sections.enroll(user.id, section.id, [context_role], status)

    %{
      user_token: user_token,
      enrollment: enrollment,
      encode64_token: encode64_token
    }
  end

  describe "Users Invite view" do
    setup [:create_section_and_user]

    test "can be accessed for a non existing token", %{conn: conn} do
      {:ok, view, _html} = live(conn, users_invite_url("non-existing-token"))

      assert has_element?(view, "h3", "This invitation has expired or does not exist")
    end

    test "can be accessed for a rejected invitation", %{conn: conn, section: section, user: user} do
      %{encode64_token: encode64_token} =
        insert_invitation_token_and_enrollment(
          user,
          section,
          "a_token_already_rejected",
          "student",
          :rejected
        )

      {:ok, view, _html} = live(conn, users_invite_url(encode64_token))

      assert has_element?(view, "h3", "This invitation has already been rejected")
    end

    test "can be accessed for a already accepted invitation", %{
      conn: conn,
      section: section,
      user: user
    } do
      %{encode64_token: encode64_token} =
        insert_invitation_token_and_enrollment(
          user,
          section,
          "a_pending_invitation_token",
          "student",
          :enrolled
        )

      {:ok, view, _html} = live(conn, users_invite_url(encode64_token))

      assert has_element?(view, "h3", "This invitation has already been redeemed.")
      assert has_element?(view, "a[href='/sections/#{section.slug}']", "Go to course")
    end

    test "can be accessed for a pending invitation", %{conn: conn, section: section, user: user} do
      %{encode64_token: encode64_token} =
        insert_invitation_token_and_enrollment(
          user,
          section,
          "a_pending_invitation_token",
          "student"
        )

      {:ok, view, _html} = live(conn, users_invite_url(encode64_token))

      assert has_element?(view, "h1", "Invitation to #{section.title}")
      assert has_element?(view, "button", "Accept")
      assert has_element?(view, "button", "Reject invitation")
    end

    test "a non existing student can accept an invitation", %{conn: conn, section: section} do
      non_existing_student = non_existing_user()

      %{encode64_token: encode64_token, enrollment: initial_enrollment} =
        insert_invitation_token_and_enrollment(
          non_existing_student,
          section,
          "a_pending_invitation_token",
          "student"
        )

      assert initial_enrollment.status == :pending_confirmation

      {:ok, view, _html} = live(conn, users_invite_url(encode64_token))

      view
      |> element("button", "Accept")
      |> render_click()

      # new user is required to register

      stub_recaptcha()
      stub_current_time(~U[2024-12-20 20:00:00Z])

      view
      |> element("#registration_form")
      |> render_change(%{
        "user" => %{
          "family_name" => "Messi",
          "given_name" => "Lionel",
          "password" => "a_valid_password",
          "password_confirmation" => "a_valid_password"
        }
      })

      view
      |> element("#registration_form")
      |> render_submit()

      just_created_user =
        Accounts.get_user_by_email_and_password(non_existing_student.email, "a_valid_password")

      updated_enrollment = Sections.get_enrollment(section.slug, non_existing_student.id)

      assert just_created_user.name == "Lionel Messi"
      assert just_created_user.email == non_existing_student.email
      assert just_created_user.independent_learner
      assert just_created_user.invitation_accepted_at == ~U[2024-12-20 20:00:00Z]
      assert just_created_user.email_confirmed_at == ~U[2024-12-20 20:00:00Z]
      assert just_created_user.email_verified

      assert updated_enrollment.status == :enrolled
    end

    test "a social login student can accept an invitation", %{conn: conn, section: section} do
      social_student = social_login_user()

      conn = log_in_user(conn, social_student)

      %{encode64_token: encode64_token, enrollment: initial_enrollment} =
        insert_invitation_token_and_enrollment(
          social_student,
          section,
          "a_pending_invitation_token",
          "student"
        )

      assert initial_enrollment.status == :pending_confirmation

      {:ok, view, _html} = live(conn, users_invite_url(encode64_token))

      view
      |> element("button", "Accept")
      |> render_click()

      updated_enrollment = Sections.get_enrollment(section.slug, social_student.id)

      assert updated_enrollment.status == :enrolled
    end

    test "a social login instructor can accept an invitation", %{conn: conn, section: section} do
      social_student = social_login_user()

      conn = log_in_user(conn, social_student)

      %{encode64_token: encode64_token, enrollment: initial_enrollment} =
        insert_invitation_token_and_enrollment(
          social_student,
          section,
          "a_pending_invitation_token",
          "instructor"
        )

      assert initial_enrollment.status == :pending_confirmation

      {:ok, view, _html} = live(conn, users_invite_url(encode64_token))

      view
      |> element("button", "Accept")
      |> render_click()

      updated_enrollment = Sections.get_enrollment(section.slug, social_student.id)

      assert updated_enrollment.status == :enrolled
    end

    test "an existing student can accept an invitation", %{conn: conn, section: section} do
      existing_student = user_fixture()

      %{encode64_token: encode64_token, enrollment: initial_enrollment} =
        insert_invitation_token_and_enrollment(
          existing_student,
          section,
          "a_pending_invitation_token",
          "student"
        )

      assert initial_enrollment.status == :pending_confirmation

      {:ok, view, _html} = live(conn, users_invite_url(encode64_token))

      view
      |> element("button", "Accept")
      |> render_click()

      view
      |> element("#login_form")
      |> render_submit(%{
        "user" => %{
          "email" => existing_student.email,
          "password" => "hello world!"
        }
      })

      updated_enrollment = Sections.get_enrollment(section.slug, existing_student.id)

      assert updated_enrollment.status == :enrolled
    end

    test "an existing instructor can accept an invitation", %{conn: conn, section: section} do
      existing_instructor = user_fixture()

      %{encode64_token: encode64_token, enrollment: initial_enrollment} =
        insert_invitation_token_and_enrollment(
          existing_instructor,
          section,
          "a_pending_invitation_token",
          "instructor"
        )

      assert initial_enrollment.status == :pending_confirmation

      {:ok, view, _html} = live(conn, users_invite_url(encode64_token))

      view
      |> element("button", "Accept")
      |> render_click()

      view
      |> element("#login_form")
      |> render_submit(%{
        "user" => %{
          "email" => existing_instructor.email,
          "password" => "hello world!"
        }
      })

      updated_enrollment = Sections.get_enrollment(section.slug, existing_instructor.id)

      assert updated_enrollment.status == :enrolled
    end

    test "a non existing instructor can accept an invitation", %{conn: conn, section: section} do
      non_existing_instructor = non_existing_user()

      %{encode64_token: encode64_token, enrollment: initial_enrollment} =
        insert_invitation_token_and_enrollment(
          non_existing_instructor,
          section,
          "a_pending_invitation_token",
          "instructor"
        )

      assert initial_enrollment.status == :pending_confirmation

      {:ok, view, _html} = live(conn, users_invite_url(encode64_token))

      view
      |> element("button", "Accept")
      |> render_click()

      # new user is required to register

      stub_recaptcha()
      stub_current_time(~U[2024-12-20 20:00:00Z])

      view
      |> element("#registration_form")
      |> render_change(%{
        "user" => %{
          "family_name" => "Di Maria",
          "given_name" => "Angelito",
          "password" => "a_valid_password",
          "password_confirmation" => "a_valid_password"
        }
      })

      view
      |> element("#registration_form")
      |> render_submit()

      just_created_user =
        Accounts.get_user_by_email_and_password(non_existing_instructor.email, "a_valid_password")

      updated_enrollment =
        Sections.get_enrollment(section.slug, non_existing_instructor.id)
        |> Oli.Repo.preload([:context_roles])

      assert just_created_user.name == "Angelito Di Maria"
      assert just_created_user.email == non_existing_instructor.email
      assert just_created_user.independent_learner
      assert just_created_user.invitation_accepted_at == ~U[2024-12-20 20:00:00Z]
      assert just_created_user.email_confirmed_at == ~U[2024-12-20 20:00:00Z]
      assert just_created_user.email_verified

      assert updated_enrollment.status == :enrolled
    end

    test "a non existing student can reject an invitation", %{conn: conn, section: section} do
      non_existing_student = non_existing_user()

      %{encode64_token: encode64_token, enrollment: initial_enrollment} =
        insert_invitation_token_and_enrollment(
          non_existing_student,
          section,
          "a_pending_invitation_token",
          "student"
        )

      assert initial_enrollment.status == :pending_confirmation

      {:ok, view, _html} = live(conn, users_invite_url(encode64_token))

      view
      |> element("button", "Reject invitation")
      |> render_click()

      updated_enrollment =
        Sections.get_enrollment(section.slug, non_existing_student.id, filter_by_status: false)

      assert updated_enrollment.status == :rejected
    end

    test "a non existing instructor can reject an invitation", %{conn: conn, section: section} do
      non_existing_instructor = non_existing_user()

      %{encode64_token: encode64_token, enrollment: initial_enrollment} =
        insert_invitation_token_and_enrollment(
          non_existing_instructor,
          section,
          "a_pending_invitation_token",
          "instructor"
        )

      assert initial_enrollment.status == :pending_confirmation

      {:ok, view, _html} = live(conn, users_invite_url(encode64_token))

      view
      |> element("button", "Reject invitation")
      |> render_click()

      updated_enrollment =
        Sections.get_enrollment(section.slug, non_existing_instructor.id, filter_by_status: false)

      assert updated_enrollment.status == :rejected
    end

    test "social login student can reject an invitation", %{conn: conn, section: section} do
      social_student = social_login_user()

      %{encode64_token: encode64_token, enrollment: initial_enrollment} =
        insert_invitation_token_and_enrollment(
          social_student,
          section,
          "a_pending_invitation_token",
          "student"
        )

      assert initial_enrollment.status == :pending_confirmation

      {:ok, view, _html} = live(conn, users_invite_url(encode64_token))

      view
      |> element("button", "Reject invitation")
      |> render_click()

      updated_enrollment =
        Sections.get_enrollment(section.slug, social_student.id, filter_by_status: false)

      assert updated_enrollment.status == :rejected
    end

    test "a logged in existing student gets redirected to the course as soon as the invitation is accepted",
         %{conn: conn, section: section} do
      existing_student = user_fixture()

      conn = log_in_user(conn, existing_student)

      %{encode64_token: encode64_token, enrollment: initial_enrollment} =
        insert_invitation_token_and_enrollment(
          existing_student,
          section,
          "a_pending_invitation_token",
          "student"
        )

      assert initial_enrollment.status == :pending_confirmation

      {:ok, view, _html} = live(conn, users_invite_url(encode64_token))

      view
      |> element("button", "Accept")
      |> render_click()

      updated_enrollment =
        Sections.get_enrollment(section.slug, existing_student.id, filter_by_status: false)

      assert updated_enrollment.status == :enrolled

      assert_redirect(view, ~p"/sections/#{section.slug}")
    end

    test "a existing student needs to provide password if logged in with an account that does not match the invitation",
         %{conn: conn, section: section} do
      another_existing_account = user_fixture()
      existing_student = user_fixture()

      conn = log_in_user(conn, another_existing_account)

      %{encode64_token: encode64_token, enrollment: initial_enrollment} =
        insert_invitation_token_and_enrollment(
          existing_student,
          section,
          "a_pending_invitation_token",
          "student"
        )

      assert initial_enrollment.status == :pending_confirmation

      {:ok, view, _html} = live(conn, users_invite_url(encode64_token))

      view
      |> element("button", "Accept")
      |> render_click()

      # sees a warning that the invitation is for another account
      assert view
             |> element("p[role='account warning']")
             |> render() =~
               "<p role=\"account warning\" class=\"text-white\">\n      You are currently logged in as <strong>#{another_existing_account.email}</strong>.<br/>\n      You will be automatically logged in as <strong>#{existing_student.email}</strong>\n      to access your invitation to <strong>&quot;#{section.title}&quot;</strong>\n      Course.\n    </p>"

      # and can finish the process by providing the password
      view
      |> element("#login_form")
      |> render_submit(%{user: %{email: existing_student.email, password: "hello world!"}})

      updated_enrollment =
        Sections.get_enrollment(section.slug, existing_student.id, filter_by_status: false)

      assert updated_enrollment.status == :enrolled
    end

    test "the background image is set depending on the invitation role", %{
      conn: conn,
      section: section
    } do
      %{encode64_token: encode64_token} =
        insert_invitation_token_and_enrollment(
          user_fixture(),
          section,
          "a_pending_invitation_token",
          "student"
        )

      {:ok, view, _html} = live(conn, users_invite_url(encode64_token))

      assert has_element?(view, "svg[id='student_sign_in_background']")

      %{encode64_token: encode64_token} =
        insert_invitation_token_and_enrollment(
          user_fixture(),
          section,
          "another_pending_invitation_token",
          "instructor"
        )

      {:ok, view, _html} = live(conn, users_invite_url(encode64_token))

      assert has_element?(view, "svg[id='instructor_sign_in_background']")
    end
  end
end
