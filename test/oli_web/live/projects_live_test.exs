defmodule OliWeb.Projects.ProjectsLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Oli.Authoring.Course
  alias Oli.Accounts
  alias OliWeb.Projects.State
  alias Oli.Seeder

  def merge_changes(changes, state) do
    Map.merge(state, Enum.reduce(changes, %{}, fn {k, v}, m -> Map.put(m, k, v) end))
  end

  describe "projects live state" do
    setup do
      map1 = Seeder.base_project_with_resource2()
      Seeder.another_project(map1.author, map1.institution, "Apple")
      # sleep to ensure Zebra project is created much later
      :timer.sleep(2000)
      Seeder.another_project(map1.author, map1.institution, "Zebra")

      map1
    end

    test "sorting", %{author: author} do
      projects = Course.get_projects_for_author(author)
      author_projects = Accounts.project_authors(Enum.map(projects, fn %{id: id} -> id end))

      state = State.initialize_state(author, projects, author_projects)

      assert length(state.projects) == 3
      assert state.sort_by == "title"
      assert state.sort_order == "asc"
      assert hd(state.projects).title == "Apple"

      state = State.sort_projects(state, "title", "desc") |> merge_changes(state)
      assert state.sort_by == "title"
      assert state.sort_order == "desc"
      assert hd(state.projects).title == "Zebra"

      state = State.sort_projects(state, "created", "desc") |> merge_changes(state)
      assert state.sort_by == "created"
      assert state.sort_order == "desc"
      assert hd(state.projects).title == "Zebra"
    end
  end

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
