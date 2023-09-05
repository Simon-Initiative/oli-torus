defmodule OliWeb.Common.PowTest do
  use OliWeb.ConnCase

  import Oli.Factory

  alias Oli.Accounts
  alias Oli.Accounts.User
  alias Oli.Delivery.Sections
  alias Oli.Seeder
  alias OliWeb.Router.Helpers, as: Routes

  @user_email "testing@example.edu"

  @user_form_attrs %{
    email: @user_email,
    given_name: "me",
    family_name: "too",
    password: "passingby",
    password_confirmation: "passingby"
  }

  describe "pow author" do
    setup [:setup_section]

    test "handles new session", %{conn: conn, author: author} do
      conn =
        conn
        |> get(Routes.authoring_pow_session_path(conn, :new))

      assert html_response(conn, 200) =~ "Authoring Sign In"

      # sign author in
      conn =
        recycle(conn)
        |> post(Routes.authoring_pow_session_path(conn, :create),
          user: %{email: author.email, password: "password123"}
        )

      assert html_response(conn, 302) =~
               Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive)

      # author who is already signed in should be automatically redirected away from sign in page
      conn =
        recycle_author_session(conn, author)
        |> get(Routes.authoring_pow_session_path(conn, :new))

      assert html_response(conn, 302) =~
               Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive)
    end

    test "shows auth providers sign in buttons", %{conn: conn} do
      conn =
        conn
        |> get(Routes.authoring_pow_session_path(conn, :new))

      response = html_response(conn, 200)

      assert response =~ "Sign in with Google"
      assert response =~ "div class=\"google-auth-container\""

      assert response =~ "Sign in with Github"
      assert response =~ "div class=\"github-auth-container\""
    end
  end

  describe "pow user" do
    setup [:setup_section]

    test "handles successful new session for non LMS user", %{conn: conn, user: user} do
      conn =
        conn
        |> get(Routes.pow_session_path(conn, :new))

      assert html_response(conn, 200) =~ "Learner/Educator Sign In"

      assert html_response(conn, 200) =~
               "This sign in page is for <b>Independent Learner and Educator</b> accounts."

      # sign user in
      conn =
        recycle(conn)
        |> post(Routes.pow_session_path(conn, :create),
          user: %{email: user.email, password: "password123"}
        )

      assert html_response(conn, 302) =~
               ~p"/sections"

      # user who is already signed in should be automatically redirected away from sign in page
      conn =
        recycle_user_session(conn, user)
        |> get(Routes.pow_session_path(conn, :new))

      assert html_response(conn, 302) =~
               ~p"/sections"
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
      user = insert(:user)
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

      assert response =~ "Sign in with Google"
      assert response =~ "div class=\"google-auth-container\""

      assert response =~ "Sign in with Github"
      assert response =~ "div class=\"github-auth-container\""
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

    test "shows auth providers sign in buttons", %{conn: conn} do
      conn =
        conn
        |> get(Routes.pow_registration_path(conn, :new))

      response = html_response(conn, 200)

      assert response =~ "Sign in with Google"
      assert response =~ "div class=\"google-auth-container\""

      assert response =~ "Sign in with Github"
      assert response =~ "div class=\"github-auth-container\""
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

  describe "pow author signup" do
    test "shows auth providers sign in buttons", %{conn: conn} do
      conn =
        conn
        |> get(Routes.authoring_pow_registration_path(conn, :new))

      response = html_response(conn, 200)

      assert response =~ "Sign in with Google"
      assert response =~ "div class=\"google-auth-container\""

      assert response =~ "Sign in with Github"
      assert response =~ "div class=\"github-auth-container\""
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

      refute response =~ "Sign in with Google"
      refute response =~ "Sign in with Github"
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

    {:ok, publication} = Oli.Publishing.publish_project(project, "some changes")

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
