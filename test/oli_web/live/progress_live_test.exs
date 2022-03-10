defmodule OliWeb.ProgressLiveTest do
  use ExUnit.Case
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  defp live_view_student_resource_route(section_slug, user_id, resource_id) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Progress.StudentResourceView,
      section_slug,
      user_id,
      resource_id
    )
  end

  describe "user cannot access when is not logged in" do
    setup [:create_resource]

    test "redirects to new session when accessing the student resource view", %{
      conn: conn,
      section: section,
      resource: resource,
      user: user
    } do
      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section.slug}%2Fprogress%2F#{user.id}%2F#{resource.id}&section=#{section.slug}"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_student_resource_route(section.slug, user.id, resource.id))
    end
  end

  describe "user cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn, :create_resource]

    test "redirects to section enroll page when accessing the student resource view", %{
      conn: conn,
      section: section,
      resource: resource,
      user: user
    } do
      conn = get(conn, live_view_student_resource_route(section.slug, user.id, resource.id))

      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section.slug}%2Fprogress%2F#{user.id}%2F#{resource.id}&amp;section=#{section.slug}"

      assert conn
             |> get(live_view_student_resource_route(section.slug, user.id, resource.id))
             |> html_response(302) =~
               "<html><body>You are being <a href=\"#{redirect_path}\">redirected</a>.</body></html>"
    end
  end

  describe "student resource" do
    setup [:admin_conn, :create_resource]

    test "loads student resource progress data correctly", %{
      conn: conn,
      section: section,
      resource: resource,
      user: user
    } do
      {:ok, view, _html} =
        live(conn, live_view_student_resource_route(section.slug, user.id, resource.id))

      html = render(view)
      assert html =~ "Details"
      assert html =~ "Attempt History"
    end
  end

  def create_resource(_context) do
    project = insert(:project)
    section = insert(:section)
    user = insert(:user)

    section_project_publication =
      insert(:section_project_publication, %{section: section, project: project})

    revision = insert(:revision)

    insert(:section_resource, %{
      section: section,
      project: project,
      resource_id: revision.resource.id
    })

    insert(:published_resource, %{
      resource: revision.resource,
      revision: revision,
      publication: section_project_publication.publication
    })

    {:ok, section: section, resource: revision.resource, user: user}
  end
end
