defmodule OliWeb.WorkspaceControllerTest do
  use OliWeb.ConnCase
  alias Oli.Repo
  alias Oli.Seeder

  describe "projects" do
    test "displays the projects page", %{conn: conn} do
      {:ok, conn: conn, author: _author} = author_conn(%{conn: conn})
      conn = get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive))
      assert html_response(conn, 200) =~ "Projects"
    end

    test "author has projects -> displays projects", %{conn: conn} do
      {:ok, conn: conn, author: author} = author_conn(%{conn: conn})
      make_n_projects(3, author)

      conn = get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive))
      assert length(Repo.preload(author, [:projects]).projects) == 3
      assert !(html_response(conn, 200) =~ "None exist")
    end

    test "author has no projects -> displays no projects", %{conn: conn} do
      {:ok, conn: conn, author: author} = author_conn(%{conn: conn})
      make_n_projects(0, author)

      conn = get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive))
      assert Enum.empty?(Repo.preload(author, [:projects]).projects)
      assert html_response(conn, 200) =~ "None exist"
    end

    test "Has a `create project` button", %{conn: conn} do
      {:ok, conn: conn, author: _author} = author_conn(%{conn: conn})
      conn = get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive))
      assert html_response(conn, 200) =~ "New Project"
    end

    test "login fails if author is deleted", %{conn: conn} do
      {:ok, conn: conn, author: author} = author_conn(%{conn: conn})

      {:ok, _} = Oli.Accounts.delete_author(author)

      conn = get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive))
      assert html_response(conn, 302) =~ "You are being <a href=\"/authoring/session/new"
    end

    test "can still access the projects page if an author is deleted", %{conn: conn} do
      %{author: author, author2: author2} = Seeder.base_project_with_resource2()

      {:ok, _} = Oli.Accounts.delete_author(author)

      conn =
        Pow.Plug.assign_current_user(conn, author2, OliWeb.Pow.PowHelpers.get_pow_config(:author))

      conn = get(conn, Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive))
      assert html_response(conn, 200) =~ "Projects"
      assert html_response(conn, 200) =~ "Example Open and Free Course"
    end
  end

  describe "account" do
    setup [:author_conn]

    test "displays the page", %{conn: conn} do
      conn = get(conn, Routes.live_path(conn, OliWeb.Workspaces.AccountDetailsLive))
      assert html_response(conn, 200) =~ "Account"
    end

    test "shows a sign out link", %{conn: conn} do
      conn =
        conn
        |> get(Routes.live_path(conn, OliWeb.Workspaces.AccountDetailsLive))

      assert html_response(conn, 200) =~ "Sign out"
    end
  end
end
