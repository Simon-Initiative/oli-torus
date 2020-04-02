defmodule OliWeb.ProjectControllerTest do
  use OliWeb.ConnCase
  alias Oli.Repo
  alias Oli.Course

  @basic_get_routes [:overview, :objectives, :curriculum, :publish, :insights]
  setup [:author_project_conn]

  describe "authorization" do
    test "all get routes redirect to workspace path when attempting to view a project that does not exist", %{conn: conn} do
      @basic_get_routes
        |> Enum.each(fn path -> unauthorized_redirect(conn, path, "does not exist") end)
      end
    end

    test "author can not access projects that do not belong to them", %{conn: conn, author: author} do
      {:ok, author: _author2, project: project2} = author_project()
      conn = Plug.Test.init_test_session(conn, current_author_id: author.id)
      @basic_get_routes
        |> Enum.each(fn path -> unauthorized_redirect(conn, path, project2.slug) end)
    end

  describe "overview" do
    test "displays the page", %{conn: conn, project: project} do
      conn = get(conn, Routes.project_path(conn, :curriculum, project.slug))
      assert html_response(conn, 200) =~ "Overview"
    end
  end

  describe "objectives" do
    test "displays the page", %{conn: conn, project: project} do
      conn = get(conn, Routes.project_path(conn, :curriculum, project.slug))
      assert html_response(conn, 200) =~ "Objectives"
    end
  end

  describe "curriculum" do
    test "displays the page", %{conn: conn, project: project} do
      conn = get(conn, Routes.project_path(conn, :curriculum, project.slug))
      assert html_response(conn, 200) =~ "Curriculum"
    end
  end

  describe "publish" do
    test "displays the page", %{conn: conn, project: project} do
      conn = get(conn, Routes.project_path(conn, :curriculum, project.slug))
      assert html_response(conn, 200) =~ "Publish"
    end
  end

  describe "insights" do
    test "displays the page", %{conn: conn, project: project} do
      conn = get(conn, Routes.project_path(conn, :curriculum, project.slug))
      assert html_response(conn, 200) =~ "Insights"
    end
  end

  describe "create a project" do
    setup do
      {:ok, transaction} = Course.create_project("test project", author_fixture())
      {:ok, %{transaction: transaction}}
    end

    test "creates a new family", %{transaction: %{family: family}} do
      assert !is_nil(family)
    end

    test "creates a new project tied to the family", %{transaction: %{project: project, family: family}} do
      project = Repo.preload(project, [:family])
      assert project.family.slug == family.slug
    end

    test "associates the currently logged in author with the new project", %{transaction: %{author: author, project: project}} do
      author = Repo.preload(author, [:projects])
      assert Enum.find(author.projects, false, fn candidate -> candidate == project end)
    end

    test "creates a new container resource", %{transaction: %{resource: resource}} do
      assert resource != nil
    end

    test "creates a new resource revision for the container", %{transaction: %{resource: resource, resource_revision: resource_revision}} do
      revision = Repo.preload(resource_revision, [:resource])
      assert revision.slug =~ "root_container"
      assert revision.resource == resource
    end

    test "creates a new publication associated with the project and containing the container resource", %{transaction: %{publication: publication, resource: resource, project: project}} do
      assert Enum.find(publication.root_resources, fn candidate_id -> candidate_id == resource.id end)
      publication = Repo.preload(publication, [:project])
      assert publication.project == project
    end
  end

  defp author_project_conn(%{conn: conn}) do
    author = author_fixture()
    [project | _rest] = make_n_projects(1, author)
    conn = Plug.Test.init_test_session(conn, current_author_id: author.id)

    {:ok, conn: conn, author: author, project: project}
  end

  defp unauthorized_redirect(conn, path, project) do
    conn = get(conn, Routes.project_path(conn, path, project))
    assert redirected_to(conn) == Routes.workspace_path(conn, :projects)
  end

  defp author_project() do
    author = author_fixture()
    [project | _rest] = make_n_projects(1, author)
    {:ok, author: author, project: project}
  end

end
