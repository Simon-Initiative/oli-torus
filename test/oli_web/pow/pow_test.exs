defmodule OliWeb.Common.PowTest do
  use OliWeb.ConnCase

  alias Oli.Seeder
  alias OliWeb.Router.Helpers, as: Routes

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

  defp setup_section(_) do
    author = author_fixture(%{password: "password123", password_confirmation: "password123"})
    user = user_fixture(%{password: "password123", password_confirmation: "password123"})

    %{project: project, institution: institution} = Seeder.base_project_with_resource(author)

    {:ok, publication} = Oli.Publishing.publish_project(project)

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
