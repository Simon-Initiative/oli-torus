defmodule OliWeb.WorkspaceControllerTest do
  use OliWeb.ConnCase

  describe "projects" do
    setup [:author_conn]

    test "displays the projects page", %{conn: conn} do
      conn = get(conn, Routes.workspace_path(conn, :projects))
      assert html_response(conn, 200) =~ "Projects"
    end

    test "author has projects -> displays all projects", %{conn: conn, author: author} do
      _projects = make_n_projects(3, author)
      conn = get(conn, Routes.workspace_path(conn, :projects))
      assert length conn.assigns.projects == 3
    end

    test "author has no projects -> displays no projects", %{conn: conn, author: author} do
      _projects = make_n_projects(0, author)
      conn = get(conn, Routes.workspace_path(conn, :projects))
      assert length conn.assigns.projects == 0
    end

    test "directs to project#create to create a new project"
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
