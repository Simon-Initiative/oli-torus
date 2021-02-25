defmodule OliWeb.DeliveryControllerTest do
  use OliWeb.ConnCase

  alias Oli.Accounts

  describe "delivery_controller index" do
    setup [:setup_session]

    test "handles student with no section", %{conn: conn} do
      conn = conn
        |> put_session(:lti_1p3_params, "student-no-section-params-key")
        |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 200) =~ "Your instructor has not configured this course section. Please check back soon."
    end

    test "handles user with student and instructor roles with no section", %{conn: conn} do
      conn = conn
        |> put_session(:lti_1p3_params, "student-instructor-no-section-params-key")
        |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 200) =~ "<h3>Getting Started</h3>"
      assert html_response(conn, 200) =~ "Let's get started by creating a section for your course."
      assert html_response(conn, 200) =~ "Link an Existing Account"
    end

    test "handles student with section", %{conn: conn} do
      conn = conn
      |> put_session(:lti_1p3_params, "student-params-key")
      |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 302) =~ "redirected"
    end

    test "handles instructor with no linked account", %{conn: conn, user: _user} do
      conn = conn
        |> put_session(:lti_1p3_params, "instructor-no-section-params-key")
        |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 200) =~ "<h3>Getting Started</h3>"
      assert html_response(conn, 200) =~ "Let's get started by creating a section for your course."
      assert html_response(conn, 200) =~ "Link an Existing Account"
    end

    test "handles instructor with no section", %{conn: conn, user: user} do
      {:ok, _user} = Accounts.update_user(user, %{author_id: 1})
      conn = conn
        |> put_session(:lti_1p3_params, "instructor-no-section-params-key")
        |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 200) =~ "<h3>Select a Project</h3>"
    end

    test "handles instructor with section", %{conn: conn, user: user} do
      {:ok, _user} = Accounts.update_user(user, %{author_id: 1})
      conn = conn
        |> put_session(:lti_1p3_params, "instructor-params-key")
        |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 302) =~ "redirect"
    end

    test "handles instructor create section", %{conn: conn, project: project, user: user, publication: publication} do
      {:ok, _user} = Accounts.update_user(user, %{author_id: 1})
      conn = conn
        |> put_session(:lti_1p3_params, "instructor-no-section-params-key")
        |> post(Routes.delivery_path(conn, :create_section, %{ project_id: project.id, publication_id: publication.id }))

      assert html_response(conn, 302) =~ "redirect"
    end

  end

  describe "delivery_controller link_account" do
    setup [:setup_session]

    test "renders link account form", %{conn: conn} do
      conn = conn
        |> get(Routes.delivery_path(conn, :link_account))

      assert html_response(conn, 200) =~ "Link Existing Account"
    end
  end

  describe "delivery_controller process_link_account_provider" do
    setup [:setup_session]

    test "processes link account for provider", %{conn: conn} do

      conn = conn
        |> get(Routes.delivery_path(conn, :process_link_account_provider, :google))

      assert html_response(conn, 302) =~ "redirect"
    end
  end

  describe "delivery_controller process_link_account_user" do
    setup [:setup_session]

    test "processes link account for user email authentication failure", %{conn: conn, author: author} do

      author_params = author
        |> Map.from_struct()
        |> Map.put(:password, "wrong_password")
        |> Map.put(:password_confirmation, "wrong_password")

      conn = conn
        |> post(Routes.delivery_path(conn, :process_link_account_user), user: author_params)

      assert html_response(conn, 200) =~ "The provided login details did not work. Please verify your credentials, and try again."
    end

    test "processes link account for user email", %{conn: conn, author: author} do

      author_params = author
        |> Map.from_struct()
        |> Map.put(:password, "password123")
        |> Map.put(:password_confirmation, "password123")

      conn = conn
        |> post(Routes.delivery_path(conn, :process_link_account_user), user: author_params)

      assert html_response(conn, 302) =~ "redirect"
    end
  end

  defp setup_session(%{conn: conn}) do
    author = author_fixture(%{
      password: "password123",
      password_confirmation: "password123",
    })

    %{project: project, institution: institution, publication: publication} = Oli.Seeder.base_project_with_resource(author)

    tool_jwk = jwk_fixture()
    registration = registration_fixture(%{institution_id: institution.id, tool_jwk_id: tool_jwk.id})
    deployment = deployment_fixture(%{registration_id: registration.id})
    section = section_fixture(%{institution_id: institution.id, lti_1p3_deployment_id: deployment.id, project_id: project.id, publication_id: publication.id})
    user = user_fixture()

    %{ project: project, publication: publication } = project_fixture(author)

    cache_lti_params("student-params-key", %{
      "iss" => registration.issuer,
      "aud" => registration.client_id,
      "sub" => "student-sub",
      "exp" => Timex.now |> Timex.add(Timex.Duration.from_hours(1)) |> Timex.to_unix,
      "https://purl.imsglobal.org/spec/lti/claim/context" => %{
        "id" => section.context_id,
        "title" => section.title,
      },
      "https://purl.imsglobal.org/spec/lti/claim/roles" => [
        "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner",
      ],
      "https://purl.imsglobal.org/spec/lti/claim/deployment_id" => deployment.deployment_id,
    })

    cache_lti_params("student-no-section-params-key", %{
      "iss" => registration.issuer,
      "aud" => registration.client_id,
      "sub" => "student-sub",
      "exp" => Timex.now |> Timex.add(Timex.Duration.from_hours(1)) |> Timex.to_unix,
      "https://purl.imsglobal.org/spec/lti/claim/context" => %{
        "id" => "some-new-client-id",
        "title" => "some new title",
      },
      "https://purl.imsglobal.org/spec/lti/claim/roles" => [
        "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner",
      ],
      "https://purl.imsglobal.org/spec/lti/claim/deployment_id" => deployment.deployment_id,
    })

    cache_lti_params("instructor-params-key", %{
      "iss" => registration.issuer,
      "aud" => registration.client_id,
      "sub" => "instructor-sub",
      "exp" => Timex.now |> Timex.add(Timex.Duration.from_hours(1)) |> Timex.to_unix,
      "https://purl.imsglobal.org/spec/lti/claim/context" => %{
        "id" => section.context_id,
        "title" => section.title,
      },
      "https://purl.imsglobal.org/spec/lti/claim/roles" => [
        "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor",
      ],
      "https://purl.imsglobal.org/spec/lti/claim/deployment_id" => deployment.deployment_id,
    })

    cache_lti_params("instructor-no-section-params-key", %{
      "iss" => registration.issuer,
      "aud" => registration.client_id,
      "sub" => "instructor-create-sub",
      "exp" => Timex.now |> Timex.add(Timex.Duration.from_hours(1)) |> Timex.to_unix,
      "https://purl.imsglobal.org/spec/lti/claim/context" => %{
        "id" => "some-new-client-id",
        "title" => "some new title",
      },
      "https://purl.imsglobal.org/spec/lti/claim/roles" => [
        "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor",
      ],
      "https://purl.imsglobal.org/spec/lti/claim/deployment_id" => deployment.deployment_id,
    })

    cache_lti_params("student-instructor-no-section-params-key", %{
      "iss" => registration.issuer,
      "aud" => registration.client_id,
      "sub" => "student-instructor-sub",
      "exp" => Timex.now |> Timex.add(Timex.Duration.from_hours(1)) |> Timex.to_unix,
      "https://purl.imsglobal.org/spec/lti/claim/context" => %{
        "id" => "some-new-client-id",
        "title" => "some new title",
      },
      "https://purl.imsglobal.org/spec/lti/claim/roles" => [
        "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor",
        "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner",
      ],
      "https://purl.imsglobal.org/spec/lti/claim/deployment_id" => deployment.deployment_id,
    })

    conn = Plug.Test.init_test_session(conn, lti_1p3_params: "student-params-key")
      |> Pow.Plug.assign_current_user(user, OliWeb.Pow.PowHelpers.get_pow_config(:user))
      |> Pow.Plug.assign_current_user(author, OliWeb.Pow.PowHelpers.get_pow_config(:author))

    {:ok,
      conn: conn,
      author: author,
      institution: institution,
      user: user,
      project: project,
      publication: publication
    }
  end
end
