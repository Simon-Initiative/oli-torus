defmodule OliWeb.Workspaces.CourseAuthor.Curriculum.EditorLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Oli.Seeder

  defp live_view_route(project_slug, revision_slug, params \\ %{}),
    do: ~p"/workspaces/course_author/#{project_slug}/curriculum/#{revision_slug}/edit?#{params}"

  describe "when user is not logged in" do
    setup [:create_project_with_units_and_modules]

    test "redirects to overview", %{
      conn: conn,
      project: project,
      revisions: revisions
    } do
      redirect_path = "/workspaces/course_author"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_route(project.slug, revisions.page_revision_1))
    end
  end

  describe "when user is logged in as an instructor" do
    setup [:instructor_conn, :create_project_with_units_and_modules]

    test "redirects to overview", %{
      conn: conn,
      project: project,
      revisions: revisions
    } do
      redirect_path = "/workspaces/course_author"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_route(project.slug, revisions.page_revision_1))
    end
  end

  describe "when user is logged in as an author but not an author of the project" do
    setup [:author_conn, :create_project_with_units_and_modules]

    test "redirects to overview", %{
      conn: conn,
      project: project,
      revisions: revisions
    } do
      redirect_path = "/workspaces/course_author"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_route(project.slug, revisions.page_revision_1))
    end
  end

  describe "when author is logged in" do
    setup :create_author_project_conn

    test "redirects to overview if revision not found", %{
      conn: conn,
      project: project
    } do
      redirect_path = "/workspaces/course_author"

      {:error, {:live_redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_route(project.slug, "non-existent-slug"))
    end

    test "displays revision editor", %{
      conn: conn,
      project: project,
      revision: revision
    } do
      {:ok, view, _html} = live(conn, live_view_route(project.slug, revision.slug))

      assert element(view, "#page_editor-container")
      assert element(view, "#collab-space-#{project.slug}-#{revision.slug}")
      assert element(view, "#content > nav")
    end
  end

  defp create_author_project_conn(%{conn: conn}) do
    %{project: project, author: author, revision1: revision} =
      Seeder.base_project_with_resource2()

    conn =
      Pow.Plug.assign_current_user(conn, author, OliWeb.Pow.PowHelpers.get_pow_config(:author))

    %{project: project, author: author, revision: revision, conn: conn}
  end
end
