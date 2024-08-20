defmodule OliWeb.Datashop.AnalyticsLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  describe "author cannot access when is not logged in" do
    test "redirects to new session when accessing the analytics view", %{conn: conn} do
      project = insert(:project)

      expected_path =
        "/authoring/session/new?request_path=%2Fproject%2F#{project.slug}%2Fdatashop"

      {:error,
       {:redirect,
        %{
          to: ^expected_path
        }}} =
        live(conn, live_view_analytics_route(project.slug))
    end
  end

  describe "user cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn, :create_project]

    test "redirects to new session when accessing the datashop analytics view", %{
      conn: conn,
      author: author,
      project: project
    } do
      make_project_author(project, author)

      assert conn
             |> get(live_view_analytics_route(project.slug))
             |> response(403)
    end
  end

  describe "browse section based from project" do
    setup [:admin_conn, :create_project]

    test "shows all section list", %{conn: conn, project: project} do
      section_1 = insert(:section, type: :enrollable, base_project: project)
      section_2 = insert(:section, type: :enrollable, base_project: project)
      section_3 = insert(:section, type: :enrollable)

      {:ok, view, _html} = live(conn, live_view_analytics_route(project.slug))

      assert has_element?(view, "a", section_1.title)
      assert has_element?(view, "a", section_2.title)
      refute has_element?(view, "a", section_3.title)
    end

    test "applies searching", %{conn: conn, project: project} do
      section_1 = insert(:section, type: :enrollable, base_project: project)
      section_2 = insert(:section, type: :enrollable, base_project: project)

      {:ok, view, _html} = live(conn, live_view_analytics_route(project.slug))

      assert has_element?(view, "a", section_1.title)
      assert has_element?(view, "a", section_2.title)

      render_hook(view, "text_search_change", %{value: section_1.title})

      assert has_element?(view, "a", section_1.title)
      refute has_element?(view, "a", section_2.title)

      view
      |> element("button[phx-click=\"text_search_reset\"]")
      |> render_click()

      assert has_element?(view, "a", section_1.title)
      assert has_element?(view, "a", section_2.title)
    end

    test "applies sorting", %{conn: conn, project: project} do
      section_1 = insert(:section, type: :enrollable, base_project: project)
      section_2 = insert(:section, type: :enrollable, base_project: project)

      {:ok, view, _html} = live(conn, live_view_analytics_route(project.slug))

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~ section_1.title

      view
      |> element("th[phx-click=\"paged_table_sort\"]:first-of-type")
      |> render_click(%{sort_by: "title"})

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~ section_2.title
    end

    test "applies paging", %{conn: conn, project: project} do
      [first_s | tail] =
        insert_list(26, :section, type: :enrollable, base_project: project)
        |> Enum.sort_by(& &1.title)

      last_s = List.last(tail)

      {:ok, view, _html} = live(conn, live_view_analytics_route(project.slug))

      assert has_element?(view, "##{first_s.id}")
      refute has_element?(view, "##{last_s.id}")

      view
      |> element("#header_paging button[phx-click=\"paged_table_page_change\"]", "2")
      |> render_click()

      refute has_element?(view, "##{first_s.id}")
      assert has_element?(view, "##{last_s.id}")
    end

    test "disables generate export button when no sections are selected", %{
      conn: conn,
      project: project
    } do
      insert(:section, type: :enrollable, base_project: project)

      {:ok, view, _html} = live(conn, live_view_analytics_route(project.slug))

      assert has_element?(view, "#button-generate-datashop[disabled]")
    end

    test "displays export link and regenerates export", %{conn: conn, project: project} do
      insert(:section, type: :enrollable, base_project: project)

      {:ok, view, _html} = live(conn, live_view_analytics_route(project.slug))

      full_upload_url = "upload_url"
      timestamp = DateTime.utc_now()

      # Notify that the export is available
      Oli.Authoring.Broadcaster.broadcast_datashop_export_status(
        project.slug,
        {:available, full_upload_url, timestamp}
      )

      assert has_element?(view, "a[href=#{full_upload_url}]", "Datashop")
      assert has_element?(view, "#button-regenerate-datashop", "Regenerate")
    end

    test "displays error when export fails", %{conn: conn, project: project} do
      insert(:section, type: :enrollable, base_project: project)

      {:ok, view, _html} = live(conn, live_view_analytics_route(project.slug))

      # Notify that the export failed
      Oli.Authoring.Broadcaster.broadcast_datashop_export_status(
        project.slug,
        {:error, "export failed"}
      )

      assert has_element?(view, "#button-generate-datashop", "Generate Datashop Export")

      assert render(view) =~
               "Error generating datashop snapshot. Please try again later or contact support."
    end

    defp live_view_analytics_route(project_slug) do
      Routes.live_path(OliWeb.Endpoint, OliWeb.Datashop.AnalyticsLive, project_slug)
    end

    defp create_project(_conn) do
      author = insert(:author)
      project = insert(:project, authors: [author])
      # root container
      container_resource = insert(:resource)

      container_revision =
        insert(:revision, %{
          resource: container_resource,
          objectives: %{},
          resource_type_id: Oli.Resources.ResourceType.id_for_container(),
          children: [],
          content: %{},
          deleted: false,
          slug: "root_container",
          title: "Root Container"
        })

      # Associate root container to the project

      insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})
      # Publication of project with root container
      publication =
        insert(:publication, %{
          project: project,
          published: nil,
          root_resource_id: container_resource.id
        })

      # Publish root container resource
      insert(:published_resource, %{
        publication: publication,
        resource: container_resource,
        revision: container_revision,
        author: author
      })

      [project: project, publication: publication]
    end

    defp make_project_author(project, author),
      do: insert(:author_project, project_id: project.id, author_id: author.id)
  end
end
