defmodule OliWeb.DeliveryControllerTest do
  use OliWeb.ConnCase

  alias Oli.Accounts

  describe "delivery_controller index" do
    setup [:setup_session]

    test "handles student with no section", %{conn: conn} do
      conn = conn
      |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 200) =~ "Your instructor has not configured this course section. Please check back soon."
    end

    test "handles student with section", %{conn: conn, project: project, publication: publication} do
      conn = conn
      |> post(Routes.delivery_path(conn, :create_section, %{ project_id: project.id, publication_id: publication.id }))
      |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 302) =~ "redirected"
    end

    test "handles instructor with no linked account", %{conn: conn, user: user} do
      {:ok, _user} = Accounts.update_user(user, %{roles: "Instructor"})
      conn = conn
      |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 200) =~ "<h3>Getting Started</h3>"
      assert html_response(conn, 200) =~ "Link an Existing Account"
    end

    test "handles instructor with no section", %{conn: conn, user: user} do
      {:ok, _user} = Accounts.update_user(user, %{author_id: 1, roles: "Instructor"})
      conn = conn
      |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 200) =~ "<h3>Select a Project</h3>"
    end

    test "handles instructor with section", %{conn: conn, project: project, user: user, publication: publication} do
      {:ok, _user} = Accounts.update_user(user, %{author_id: 1, roles: "Instructor"})
      conn = conn
      |> post(Routes.delivery_path(conn, :create_section, %{ project_id: project.id, publication_id: publication.id }))
      |> get(Routes.delivery_path(conn, :index))

      assert html_response(conn, 302) =~ "redirect"
    end

  end

  defp setup_session(%{conn: conn}) do
    author = author_fixture()
    institution = institution_fixture(%{ author_id: author.id })
    lti_params = build_lti_request(url_from_conn(conn), "some-secret")

    {:ok, user } = Accounts.insert_or_update_user(%{
      email: lti_params["lis_person_contact_email_primary"],
      first_name: lti_params["lis_person_name_given"],
      last_name: lti_params["lis_person_name_family"],
      user_id: lti_params["user_id"],
      user_image: lti_params["user_image"],
      roles: lti_params["roles"],
      institution_id: institution.id,
    })

    %{ project: project, publication: publication } = project_fixture(author)

    conn = Plug.Test.init_test_session(conn, current_author_id: author.id)
      |> put_session(:current_user_id, user.id)
      |> put_session(:lti_params, lti_params)

    {:ok,
      conn: conn,
      author: author,
      institution: institution,
      lti_params: lti_params,
      user: user,
      project: project,
      publication: publication
    }
  end
end
