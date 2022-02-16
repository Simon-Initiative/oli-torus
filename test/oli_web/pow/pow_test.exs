defmodule OliWeb.Common.PowTest do
  use OliWeb.ConnCase

  alias Oli.Accounts
  alias Oli.Accounts.User
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
  end

  describe "pow user" do
    setup [:setup_section]

    test "handles new session", %{conn: conn, user: user} do
      conn =
        conn
        |> get(Routes.pow_session_path(conn, :new))

      assert html_response(conn, 200) =~ "Learner Sign In"

      # sign user in
      conn =
        recycle(conn)
        |> post(Routes.pow_session_path(conn, :create),
          user: %{email: user.email, password: "password123"}
        )

      assert html_response(conn, 302) =~
               Routes.delivery_path(conn, :open_and_free_index)

      # user who is already signed in should be automatically redirected away from sign in page
      conn =
        recycle_user_session(conn, user)
        |> get(Routes.pow_session_path(conn, :new))

      assert html_response(conn, 302) =~
               Routes.delivery_path(conn, :open_and_free_index)
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

      assert html_response(conn, 200) =~ "Create a Learner Account"

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
end
