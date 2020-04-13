defmodule OliWeb.WorkspaceControllerTest do
  use OliWeb.ConnCase
  alias Oli.Repo

  describe "projects" do

    test "displays the projects page", %{conn: conn} do
      {:ok, conn: conn, author: _author} = author_conn(%{conn: conn})
      conn = get(conn, Routes.workspace_path(conn, :projects))
      assert html_response(conn, 200) =~ "Projects"
    end

    test "author has projects -> displays projects", %{conn: conn} do
      {:ok, conn: conn, author: author} = author_conn(%{conn: conn})
      make_n_projects(3, author)

      conn = get(conn, Routes.workspace_path(conn, :projects))
      assert length(Repo.preload(author, [:projects]).projects) == 3
      assert !(html_response(conn, 200) =~ "No projects")
    end

    test "author has no projects -> displays no projects", %{conn: conn} do
      {:ok, conn: conn, author: author} = author_conn(%{conn: conn})
      make_n_projects(0, author)

      conn = get(conn, Routes.workspace_path(conn, :projects))
      assert Enum.empty?(Repo.preload(author, [:projects]).projects)
      assert html_response(conn, 200) =~ "No projects"
    end

    test "Has a `create project` button", %{conn: conn} do
      {:ok, conn: conn, author: _author} = author_conn(%{conn: conn})
      conn = get(conn, Routes.workspace_path(conn, :projects))
      assert html_response(conn, 200) =~ "action=\"/project\""
    end
  end

  describe "account" do
    setup [:author_conn]

    test "displays the page", %{conn: conn} do
      conn = get(conn, Routes.workspace_path(conn, :account))
      assert html_response(conn, 200) =~ "Account"
    end

    test "shows a sign out link", %{conn: conn} do
      conn = conn
      |> get(Routes.workspace_path(conn, :account))

      assert html_response(conn, 200) =~ "Sign out"
    end
  end

  def author_conn(%{conn: conn}) do
    author = author_fixture()
    conn = Plug.Test.init_test_session(conn, current_author_id: author.id)

    {:ok, conn: conn, author: author}
  end

end
