defmodule OliWeb.Common.PowTest do
  use OliWeb.ConnCase
  use Bamboo.Test

  import Oli.Factory

  alias Oli.Accounts
  alias Oli.Accounts.{Author, User}
  alias Oli.Delivery.Sections
  alias Oli.Seeder
  alias OliWeb.Router.Helpers, as: Routes

  @user_email "testing@example.edu"
  @author_email "author@example.edu"

  @user_form_attrs %{
    email: @user_email,
    email_confirmation: @user_email,
    given_name: "me",
    family_name: "too",
    password: "passingby",
    password_confirmation: "passingby"
  }

  @author_form_attrs %{
    email: @author_email,
    email_confirmation: @author_email,
    given_name: "author",
    family_name: "example",
    password: "passingby",
    password_confirmation: "passingby"
  }

  describe "pow author" do
    setup [:setup_section]

    test "handles new session", %{conn: conn, author: author} do
      conn =
        conn
        |> get(Routes.authoring_pow_session_path(conn, :new))

      assert html_response(conn, 200) =~ "Course Author Sign In"

      assert html_response(conn, 200) =~
               "<div class=\"text-left\">\n            <span class=\"text-white text-4xl font-normal font-['Open Sans'] leading-10\">\n              Welcome to\n            </span>\n            <span class=\"text-white text-4xl font-bold font-['Open Sans'] leading-10\">\nOLI Torus\n            </span>\n          </div>"

      assert html_response(conn, 200) =~
               "Create, deliver, and continuously improve course materials."

      assert html_response(conn, 200) =~
               "Create an Account"

      # sign author in
      conn =
        recycle(conn)
        |> post(Routes.authoring_pow_session_path(conn, :create),
          user: %{email: author.email, password: "password123"}
        )

      assert html_response(conn, 302) =~
               ~p"/workspaces/course_author"

      # author who is already signed in should be automatically redirected away from sign in page
      conn =
        recycle_author_session(conn, author)
        |> get(Routes.authoring_pow_session_path(conn, :new))

      assert html_response(conn, 302) =~
               ~p"/workspaces/course_author"
    end

    test "shows auth providers sign in buttons", %{conn: conn} do
      conn =
        conn
        |> get(Routes.authoring_pow_session_path(conn, :new))

      response = html_response(conn, 200)

      assert response =~ "Continue with Google"
      assert response =~ "Continue with Github"
    end

    test "signs out user when signs in as admin", %{conn: conn, user: user} do
      admin =
        author_fixture(%{
          system_role_id: Accounts.SystemRole.role_id().system_admin
        })

      # sign user in
      conn =
        post(conn, Routes.pow_session_path(conn, :create),
          user: %{email: user.email, password: "password123"}
        )

      # sign admin in
      conn =
        post(conn, Routes.authoring_pow_session_path(conn, :create),
          user: %{email: admin.email, password: "password123"}
        )

      # User is signed out
      refute conn.assigns.current_user
      refute get_session(conn, :current_user_id)
    end
  end

  describe "pow user" do
    setup [:setup_section]

    test "handles successful new session for non LMS user", %{conn: conn, user: user} do
      conn =
        conn
        |> get(Routes.pow_session_path(conn, :new))

      assert html_response(conn, 200) =~ "Instructor Sign In"

      assert html_response(conn, 200) =~
               "<div class=\"text-left\">\n            <span class=\"text-white text-4xl font-normal font-['Open Sans'] leading-10\">\n              Welcome to\n            </span>\n            <span class=\"text-white text-4xl font-bold font-['Open Sans'] leading-10\">\nOLI Torus\n            </span>\n          </div>"

      assert html_response(conn, 200) =~
               "Gain insights into student engagement, progress, and learning patterns."

      assert html_response(conn, 200) =~
               "Create an Account"

      # assert that background is set to the default background
      assert html_response(conn, 200) =~ "fill=\"#0CAF61\""

      # sign user in
      conn =
        recycle(conn)
        |> post(Routes.pow_session_path(conn, :create),
          user: %{email: user.email, password: "password123"}
        )

      assert html_response(conn, 302) =~
               ~p"/workspaces/instructor"

      # user who is already signed in should be automatically redirected away from sign in page
      conn =
        recycle_user_session(conn, user)
        |> get(Routes.pow_session_path(conn, :new))

      assert html_response(conn, 302) =~
               ~p"/workspaces/instructor"
    end

    test "hides authoring sign in box when coming from an invitation link", %{
      conn: conn,
      user: user
    } do
      conn =
        conn
        |> get(Routes.pow_session_path(conn, :new, from_invitation_link?: true))

      assert html_response(conn, 200) =~ "Instructor Sign In"

      refute html_response(conn, 200) =~
               "Looking for Authoring or your LMS?"

      # sign user in
      conn =
        recycle(conn)
        |> post(Routes.pow_session_path(conn, :create),
          user: %{email: user.email, password: "password123"}
        )

      assert html_response(conn, 302) =~
               ~p"/workspaces/instructor"

      # user who is already signed in should be automatically redirected away from sign in page
      conn =
        recycle_user_session(conn, user)
        |> get(Routes.pow_session_path(conn, :new))

      assert html_response(conn, 302) =~
               ~p"/workspaces/instructor"
    end

    test "handles new session failure for non LMS user", %{conn: conn, user: user} do
      # sign user in
      conn =
        post(conn, Routes.pow_session_path(conn, :create),
          user: %{email: user.email, password: "bad_password"}
        )

      html = html_response(conn, 200)

      assert html =~
               "The provided login details did not work. Please verify your credentials, and try again."
    end

    test "handles new session failure for an LMS user and displays warning properly", %{
      conn: conn
    } do
      # sign user in
      user = insert(:user, %{independent_learner: false})
      insert(:lti_params, user_id: user.id)

      conn =
        post(conn, Routes.pow_session_path(conn, :create),
          user: %{email: user.email, password: "bad_password"}
        )

      html = html_response(conn, 200)

      assert html =~
               "We have detected an account using that email was previously created when you accessed the system from your LMS."
    end

    test "shows auth providers sign in buttons", %{conn: conn} do
      conn =
        conn
        |> get(Routes.pow_session_path(conn, :new))

      response = html_response(conn, 200)

      assert response =~ "Continue with Google"
      assert response =~ "Continue with Github"
    end
  end

  describe "pow learner signup" do
    setup [:configure_age_verification]

    test "returns error when age verification is not checked", %{conn: conn} do
      expect_recaptcha_http_post()

      conn =
        post(
          conn,
          Routes.pow_registration_path(conn, :create),
          %{
            user:
              Map.merge(@user_form_attrs, %{
                age_verified: "false"
              }),
            "g-recaptcha-response": "any"
          }
        )

      assert html_response(conn, 200) =~ "Create a Learner/Educator Account"

      assert html_response(conn, 200) =~
               "You must verify you are old enough to access our site in order to continue"

      refute Accounts.get_user_by(%{email: @user_email})
    end

    test "returns error when email confirmation does not match email", %{conn: conn} do
      expect_recaptcha_http_post()

      attr =
        @user_form_attrs
        |> Map.put(:email_confirmation, "email_with_typo@test.com")
        |> Map.put(:age_verified, true)

      conn =
        post(
          conn,
          Routes.pow_registration_path(conn, :create),
          %{
            user: attr,
            "g-recaptcha-response": "any"
          }
        )

      assert html_response(conn, 200) =~ "Create a Learner/Educator Account"

      assert html_response(conn, 200) =~
               "Email confirmation does not match Email"

      refute Accounts.get_user_by(%{email: @user_email})
    end

    test "creates the user when age verification is checked", %{conn: conn} do
      expect_recaptcha_http_post()

      conn =
        post(
          conn,
          Routes.pow_registration_path(conn, :create),
          %{
            user:
              Map.merge(@user_form_attrs, %{
                age_verified: "true"
              }),
            "g-recaptcha-response": "any"
          }
        )

      assert html_response(conn, 302) =~ "You are being <a href=\"/session/new\">redirected"

      assert %User{email: @user_email, email_confirmed_at: nil} =
               Accounts.get_user_by(%{email: @user_email})
    end

    test "an email confirmation flash message is set when account is created", %{conn: conn} do
      expect_recaptcha_http_post()

      conn =
        post(
          conn,
          Routes.pow_registration_path(conn, :create),
          %{
            user:
              Map.merge(@user_form_attrs, %{
                age_verified: "true"
              }),
            "g-recaptcha-response": "any"
          }
        )

      assert conn.assigns.flash["info"] ==
               "To continue, check #{@user_email} for a confirmation email.\n\nIf you don’t receive this email, check your Spam folder or verify that testing@example.edu is correct.\n\nYou can close this tab if you received the email.\n"

      assert %User{email: @user_email, email_confirmed_at: nil} =
               Accounts.get_user_by(%{email: @user_email})
    end

    test "a flash message is shown when the user is already registered",
         %{conn: conn} do
      insert(:user, %{email: @user_email, email_confirmed_at: nil})
      expect_recaptcha_http_post()

      conn =
        post(
          conn,
          Routes.pow_registration_path(conn, :create),
          %{
            user:
              Map.merge(@user_form_attrs, %{
                age_verified: "true"
              }),
            "g-recaptcha-response": "any"
          }
        )

      assert conn.assigns.flash["info"] ==
               "To continue, check #{@user_email} for a confirmation email.\n\nIf you don’t receive this email, check your Spam folder or verify that #{@user_email} is correct.\n\nYou can close this tab if you received the email.\n"

      assert %User{email: @user_email} =
               Accounts.get_user_by(%{email: @user_email})
    end

    test "shows auth providers sign in buttons", %{conn: conn} do
      conn =
        conn
        |> get(Routes.pow_registration_path(conn, :new))

      response = html_response(conn, 200)

      assert response =~ "Continue with Google"
      assert response =~ "Continue with Github"
    end
  end

  describe "confirm students on signup based on section logic" do
    setup [:setup_section]

    test "do not confirm student when section indicates to not omit student email verification",
         %{conn: conn, section: section} do
      expect_recaptcha_http_post()

      conn =
        post(
          conn,
          Routes.pow_registration_path(conn, :create),
          %{
            user:
              Map.merge(@user_form_attrs, %{
                section: section.slug
              }),
            "g-recaptcha-response": "any"
          }
        )

      assert html_response(conn, 302) =~
               "You are being <a href=\"/session/new?section=#{section.slug}\">redirected"

      assert %User{email: @user_email, email_confirmed_at: nil} =
               Accounts.get_user_by(%{email: @user_email})
    end

    test "confirm student and redirects to enroll when section indicates to omit student email confirmation",
         %{conn: conn, section: section} do
      {:ok, section} = Sections.update_section(section, %{skip_email_verification: true})
      expect_recaptcha_http_post()

      conn =
        post(
          conn,
          Routes.pow_registration_path(conn, :create),
          %{
            user:
              Map.merge(@user_form_attrs, %{
                section: section.slug
              }),
            "g-recaptcha-response": "any"
          }
        )

      assert html_response(conn, 302) =~
               "You are being <a href=\"/sections/#{section.slug}/enroll\">redirected"

      assert %User{email: @user_email} = user = Accounts.get_user_by(%{email: @user_email})
      assert user.email_confirmed_at
    end
  end

  describe "Admin" do
    setup [:admin_conn]

    test "can send password reset link to user", %{conn: conn} do
      user = insert(:user)
      user_email = user.email

      conn = post(conn, "/admin/accounts/send_user_password_reset_link", %{user_id: user.id})

      assert_delivered_email_matches(%{to: [{_, ^user_email}], subject: "Reset password link"})
      assert conn.assigns.flash["info"] == "Password reset link sent to user #{user.email}."
      assert html_response(conn, 302) =~ ~p"/admin/users/#{user.id}"
    end

    test "can send password reset link to author", %{conn: conn} do
      author = insert(:author)
      author_email = author.email

      conn = post(conn, "/admin/accounts/send_author_password_reset_link", %{user_id: author.id})

      assert_delivered_email_matches(%{to: [{_, ^author_email}], subject: "Reset password link"})
      assert conn.assigns.flash["info"] == "Password reset link sent to user #{author.email}."
      assert html_response(conn, 302) =~ ~p"/admin/authors/#{author.id}"
    end
  end

  describe "pow author signup" do
    test "shows auth providers sign in buttons", %{conn: conn} do
      conn =
        conn
        |> get(Routes.authoring_pow_registration_path(conn, :new))

      response = html_response(conn, 200)

      assert response =~ "Continue with Google"
      assert response =~ "Continue with Github"
    end

    test "a flash message is shown when the author is already registered",
         %{conn: conn} do
      insert(:author, %{email: @author_email, email_confirmed_at: nil})
      expect_recaptcha_http_post()

      conn =
        post(
          conn,
          Routes.authoring_pow_registration_path(conn, :create),
          %{
            user:
              Map.merge(@author_form_attrs, %{
                age_verified: "true"
              }),
            "g-recaptcha-response": "any"
          }
        )

      assert conn.assigns.flash["info"] ==
               "To continue, check #{@author_email} for a confirmation email.\n\nIf you don’t receive this email, check your Spam folder or verify that #{@author_email} is correct.\n\nYou can close this tab if you received the email.\n"

      assert %Author{email: @author_email} =
               Accounts.get_author_by_email(@author_email)
    end
  end

  describe "login with auth providers disabled" do
    setup [:setup_section, :reset_auth_providers_env_on_exit]

    test "does not show auth providers sign in buttons when env vars are disabled", %{conn: conn} do
      Application.put_env(:oli, :auth_providers, [])

      conn =
        conn
        |> get(Routes.authoring_pow_session_path(conn, :new))

      response = html_response(conn, 200)

      refute response =~ "Continue with Google"
      refute response =~ "Continue with Github"
    end
  end

  defp configure_age_verification(_) do
    Config.Reader.read!("test/config/age_verification_config.exs")
    |> Application.put_all_env()

    on_exit(fn ->
      Config.Reader.read!("test/config/config.exs")
      |> Application.put_all_env()
    end)
  end

  defp setup_section(_) do
    author = author_fixture(%{password: "password123", password_confirmation: "password123"})
    user = user_fixture(%{password: "password123", password_confirmation: "password123"})

    %{project: project, institution: institution} = Seeder.base_project_with_resource(author)

    {:ok, publication} = Oli.Publishing.publish_project(project, "some changes", author.id)

    section =
      section_fixture(%{
        institution_id: institution.id,
        base_project_id: project.id,
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true
      })

    %{author: author, user: user, section: section, project: project, publication: publication}
  end

  defp reset_auth_providers_env_on_exit(_) do
    auth_providers = Application.fetch_env!(:oli, :auth_providers)
    on_exit(fn -> Application.put_env(:oli, :auth_providers, auth_providers) end)
  end
end
