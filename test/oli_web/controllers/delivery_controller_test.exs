defmodule OliWeb.DeliveryControllerTest do
  use OliWeb.ConnCase

  alias Oli.Accounts

  describe "delivery_controller index" do
    setup [:setup_session]

    test "handles student with no section", %{conn: conn} do
      conn = conn
      # TODO replace with lti_params cache key
      |> put_session(:lti_params, %{
        "context_id" => "some-context-id",
        "context_title" => "some-title",
        "https://purl.imsglobal.org/spec/lti/claim/roles" => ["http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"],
      })
      |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 200) =~ "Your instructor has not configured this course section. Please check back soon."
    end

    test "handles student with section", %{conn: conn, project: project, publication: publication} do
      conn = conn
      # TODO replace with lti_params cache key
      |> put_session(:lti_params, %{
        "context_id" => "some-context-id",
        "context_title" => "some-title",
        "https://purl.imsglobal.org/spec/lti/claim/roles" => ["http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"],
      })
      |> post(Routes.delivery_path(conn, :create_section, %{ project_id: project.id, publication_id: publication.id }))
      |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 302) =~ "redirected"
    end

    test "handles instructor with no linked account", %{conn: conn, user: _user} do
      conn = conn
      # TODO replace with lti_params cache key
      |> put_session(:lti_params, %{
        "context_id" => "some-context-id",
        "context_title" => "some-title",
        "https://purl.imsglobal.org/spec/lti/claim/roles" => ["http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor"],
      })
      |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 200) =~ "<h3>Getting Started</h3>"
      assert html_response(conn, 200) =~ "Link an Existing Account"
    end

    test "handles instructor with no section", %{conn: conn, user: user} do
      {:ok, _user} = Accounts.update_user(user, %{author_id: 1})
      conn = conn
      # TODO replace with lti_params cache key
      |> put_session(:lti_params, %{
        "context_id" => "some-context-id",
        "context_title" => "some-title",
        "https://purl.imsglobal.org/spec/lti/claim/roles" => ["http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor"],
      })
      |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 200) =~ "<h3>Select a Project</h3>"
    end

    test "handles instructor with section", %{conn: conn, project: project, user: user, publication: publication} do
      {:ok, _user} = Accounts.update_user(user, %{author_id: 1})
      conn = conn
      # TODO replace with lti_params cache key
      |> put_session(:lti_params, %{
        "context_id" => "some-context-id",
        "context_title" => "some-title",
        "https://purl.imsglobal.org/spec/lti/claim/roles" => ["http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor"],
      })
      |> post(Routes.delivery_path(conn, :create_section, %{ project_id: project.id, publication_id: publication.id }))
      |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 302) =~ "redirect"
    end

  end

  defp setup_session(%{conn: conn}) do
    author = author_fixture()
    institution = institution_fixture(%{ author_id: author.id })
    user = user_fixture(%{institution_id: institution.id})

    %{ project: project, publication: publication } = project_fixture(author)

    conn = Plug.Test.init_test_session(conn, current_author_id: author.id)
      |> put_session(:current_user_id, user.id)
      # TODO replace with lti_params cache key
      |> put_session(:lti_params, %{"context_id" => "some-context-id"})

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
