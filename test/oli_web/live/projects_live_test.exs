defmodule OliWeb.Projects.ProjectsLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Oli.Accounts
  alias Oli.Seeder

  describe "projects live" do
    setup [:setup_author_project]

    test "loads correctly when there are no collaborators for a project", %{
      conn: conn,
      map: %{
        author: author,
        author2: author2
      }
    } do
      {:ok, _author} = Accounts.delete_author(author)
      {:ok, _author} = Accounts.delete_author(author2)

      conn = get(conn, "/authoring/projects")

      {:ok, _view, _} = live(conn)
    end
  end

  defp setup_author_project(%{conn: conn}) do
    map = Seeder.base_project_with_resource2()
    admin = author_fixture(%{system_role_id: Oli.Accounts.SystemRole.role_id().admin})

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> Pow.Plug.assign_current_user(admin, OliWeb.Pow.PowHelpers.get_pow_config(:author))

    {:ok, conn: conn, map: map}
  end
end
