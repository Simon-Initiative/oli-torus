defmodule OliWeb.ResourceControllerTest do
  use OliWeb.ConnCase

  alias Oli.Authoring.Editing.PageEditor

  setup [:project_seed]

  describe "edit" do
    test "renders resource editor", %{conn: conn, project: project, revision1: revision} do
      conn = get(conn, Routes.resource_path(conn, :edit, project.slug, revision.slug))

      assert html_response(conn, 200) =~
               "<div data-react-class=\"Components.PageEditor\" data-react-props=\""
    end

    test "renders truncate title when page title is too long", %{
      conn: conn,
      project: project,
      revision1: revision
    } do
      conn = get(conn, Routes.resource_path(conn, :edit, project.slug, revision.slug))

      assert html_response(conn, 200) =~
               "<h3 class=\"truncate\">\n#{revision.title}"
    end

    test "renders truncate breadcrumbs when page title is too long", %{
      conn: conn,
      project: project,
      revision1: revision
    } do
      conn = get(conn, Routes.resource_path(conn, :edit, project.slug, revision.slug))

      assert html_response(conn, 200) =~
               "<li class=\"breadcrumb-item active truncate\" aria-current=\"page\">\n  #{revision.title}\n</li>"
    end

    test "renders adaptive editor", %{
      conn: conn,
      project: project,
      adaptive_page_revision: revision
    } do
      conn = get(conn, Routes.resource_path(conn, :edit, project.slug, revision.slug))

      assert html_response(conn, 200) =~
               "<div data-react-class=\"Components.Authoring\" data-react-props=\""
    end

    test "renders error when resource does not exist", %{conn: conn, project: project} do
      conn = get(conn, Routes.resource_path(conn, :edit, project.slug, "does_not_exist"))
      assert html_response(conn, 200) =~ "Not Found"
    end

    test "renders next page links", %{
      conn: conn,
      project: project,
      revision1: revision1,
      revision2: revision2
    } do
      conn = get(conn, Routes.resource_path(conn, :preview, project.slug, revision1.slug))

      assert html_response(conn, 200) =~
               "<a class=\"page-nav-link btn\" href=\"/authoring/project/#{project.slug}/preview/#{revision2.slug}\">"
    end

    test "renders prev page links", %{
      conn: conn,
      project: project,
      revision1: revision1,
      revision2: revision2
    } do
      conn = get(conn, Routes.resource_path(conn, :preview, project.slug, revision2.slug))

      assert html_response(conn, 200) =~
               "<a class=\"page-nav-link btn\" href=\"/authoring/project/#{project.slug}/preview/#{revision1.slug}\">"
    end
  end

  describe "update resource" do
    test "valid response on valid update", %{
      conn: conn,
      project: project,
      revision1: revision,
      author: author
    } do
      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      conn =
        put(
          conn,
          Routes.resource_path(conn, :update, project.slug, revision.slug, %{
            "update" => %{"title" => "new title"}
          })
        )

      assert %{"type" => "success"} = json_response(conn, 200)
    end

    test "error response on invalid update", %{conn: conn, project: project} do
      conn =
        put(
          conn,
          Routes.resource_path(conn, :update, project.slug, "does_not_exist", %{
            "update" => %{"title" => "new title"}
          })
        )

      assert response(conn, 404)
    end
  end

  describe "preview" do
    test "renders an advanced lesson preview", %{
      conn: conn,
      project: project,
      adaptive_page_revision: adaptive_page_revision
    } do
      conn =
        get(conn, Routes.resource_path(conn, :preview, project.slug, adaptive_page_revision.slug))

      assert html_response(conn, 200) =~
               "<div data-react-class=\"Components.Delivery\" data-react-props=\""
    end

    test "renders page preview with next page links", %{
      conn: conn,
      project: project,
      revision1: revision1,
      revision2: revision2
    } do
      conn = get(conn, Routes.resource_path(conn, :preview, project.slug, revision1.slug))

      assert html_response(conn, 200) =~
               "<nav class=\"previous-next-nav d-flex flex-row\" aria-label=\"Page navigation\">"

      assert html_response(conn, 200) =~
               "<a class=\"page-nav-link btn\" href=\"/authoring/project/#{project.slug}/preview/#{revision2.slug}\">"

      assert html_response(conn, 200) =~ "<div class=\"nav-label\">Next</div>"
      assert html_response(conn, 200) =~ "<div class=\"nav-title\">#{revision2.title}</div>"
    end

    test "renders page preview with prev page links", %{
      conn: conn,
      project: project,
      revision1: revision1,
      revision2: revision2
    } do
      conn = get(conn, Routes.resource_path(conn, :preview, project.slug, revision2.slug))

      assert html_response(conn, 200) =~
               "<a class=\"page-nav-link btn\" href=\"/authoring/project/#{project.slug}/preview/#{revision1.slug}\">"

      assert html_response(conn, 200) =~ "<div class=\"nav-label\">Previous</div>"
      assert html_response(conn, 200) =~ "<div class=\"nav-title\">#{revision1.title}</div>"
    end

    test "renders page preview with hyperlink to another page", %{
      conn: conn,
      project: project,
      revision1: revision1,
      revision2: revision2
    } do
      {:ok, revision} =
        Oli.Resources.update_revision(revision1, %{
          content: create_hyperlink_content(revision2.slug)
        })

      conn = get(conn, Routes.resource_path(conn, :preview, project.slug, revision.slug))

      assert html_response(conn, 200) =~
               "<a class=\"internal-link\" href=\"/authoring/project/#{project.slug}/preview/#{revision2.slug}\">"
    end

    test "renders error when resource does not exist", %{conn: conn, project: project} do
      conn = get(conn, Routes.resource_path(conn, :preview, project.slug, "does_not_exist"))
      assert html_response(conn, 200) =~ "Not Found"
    end

    test "redirects to first resource if no revision slug is given", %{
      conn: conn,
      project: project,
      revision1: revision1
    } do
      conn = get(conn, Routes.resource_path(conn, :preview, project.slug))

      assert html_response(conn, 302) =~
               Routes.resource_path(conn, :preview, project.slug, revision1.slug)
    end
  end

  def project_seed(%{conn: conn}) do
    seeds =
      Oli.Seeder.base_project_with_resource2()
      |> Oli.Seeder.add_adaptive_page()

    conn =
      log_in_author(
        conn,
        seeds.author
      )

    {:ok, Map.merge(%{conn: conn}, seeds)}
  end
end
