defmodule OliWeb.PublishLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Delivery.Sections
  alias Oli.Resources.ResourceType
  alias OliWeb.Common.Utils

  defp live_view_publish_route(project_slug),
    do: Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.PublishView, project_slug)

  defp create_project_and_section(_conn) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    page_resource = insert(:resource)

    page_revision =
      insert(:revision,
        resource: page_resource,
        resource_type_id: ResourceType.get_id_by_type("page"),
        content: %{"model" => []},
        title: "revision A"
      )

    insert(:project_resource, %{project_id: project.id, resource_id: page_resource.id})

    container_resource = insert(:resource)

    container_revision =
      insert(:revision, %{
        resource: container_resource,
        resource_type_id: ResourceType.get_id_by_type("container"),
        children: [page_resource.id],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container"
      })

    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})

    publication =
      insert(:publication, %{
        project: project,
        root_resource_id: container_resource.id,
        published: nil
      })

    insert(:published_resource, %{
      publication: publication,
      resource: container_resource,
      revision: container_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_resource,
      revision: page_revision,
      author: author
    })

    section1 =
      insert(:section,
        title: "Example_Section1",
        base_project: project,
        type: :enrollable,
        open_and_free: true,
        registration_open: true,
        start_date: yesterday(),
        end_date: tomorrow()
      )

    section2 =
      insert(:section,
        title: "Example_Section2",
        base_project: project,
        type: :enrollable,
        open_and_free: true,
        registration_open: true,
        start_date: yesterday(),
        end_date: tomorrow()
      )

    {:ok, _sr} = Sections.create_section_resources(section1, publication)
    {:ok, _sr} = Sections.create_section_resources(section2, publication)

    [
      project: project,
      publication: publication,
      page_revision: page_revision,
      section1: section1,
      section2: section2,
      author: author,
      container_revision: container_revision
    ]
  end

  defp create_project_with_publication(_conn) do
    project = insert(:project)
    container_resource = insert(:resource)

    container_revision =
      insert(:revision, %{
        resource: container_resource,
        resource_type_id: ResourceType.get_id_by_type("container"),
        children: [],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container"
      })

    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})

    publication =
      insert(:publication, %{
        project: project,
        root_resource_id: container_resource.id,
        published: nil
      })

    insert(:published_resource, %{
      publication: publication,
      resource: container_resource,
      revision: container_revision
    })

    %{project: project}
  end

  describe "user cannot access when is not logged in" do
    test "redirects to new session when accessing the publish view", %{conn: conn} do
      project = insert(:project)

      assert conn
             |> get(live_view_publish_route(project.slug))
             |> html_response(302) =~
               "You are being <a href=\"/authoring/session/new?request_path=%2Fauthoring%2Fproject%2F#{project.slug}%2Fpublish\">redirected</a>"
    end
  end

  describe "user cannot access when is logged in as an author but is not an author of the project" do
    setup [:author_conn]

    test "redirects to projects view", %{
      conn: conn
    } do
      project = insert(:project)

      assert conn
             |> get(live_view_publish_route(project.slug))
             |> html_response(302) =~
               "You are being <a href=\"/authoring/projects\">redirected</a>"
    end
  end

  describe "user cannot access when is logged in as an instructor" do
    setup [:instructor_conn]

    test "redirects to new session when accessing the publish view as an instructor", %{
      conn: conn
    } do
      project = insert(:project)

      assert conn
             |> get(live_view_publish_route(project.slug))
             |> html_response(302) =~
               "You are being <a href=\"/authoring/session/new?request_path=%2Fauthoring%2Fproject%2F#{project.slug}%2Fpublish\">redirected</a>"
    end
  end

  describe "user cannot access when is logged in as a student" do
    setup [:user_conn]

    test "redirects to new session when accessing the publish view as a student", %{
      conn: conn
    } do
      project = insert(:project)

      assert conn
             |> get(live_view_publish_route(project.slug))
             |> html_response(302) =~
               "You are being <a href=\"/authoring/session/new?request_path=%2Fauthoring%2Fproject%2F#{project.slug}%2Fpublish\">redirected</a>"
    end
  end

  describe "user can access when is logged in as an author, is not a system admin but is author of the project" do
    setup [:create_project_and_section]

    test "returns publish view for a project", %{
      conn: conn,
      author: author,
      project: project
    } do
      conn =
        conn
        |> Pow.Plug.assign_current_user(author, OliWeb.Pow.PowHelpers.get_pow_config(:author))
        |> get(live_view_publish_route(project.slug))

      assert html_response(conn, 200) =~ "Publication Details"
    end
  end

  describe "user can access when is logged in as system admin" do
    setup [:admin_conn, :create_project_and_section]

    test "returns publish view for a project", %{
      conn: conn,
      project: project
    } do
      conn = get(conn, live_view_publish_route(project.slug))

      assert html_response(conn, 200)
    end
  end

  describe "publish view" do
    setup [:admin_conn, :create_project_and_section]

    test "shows publication details", %{
      conn: conn,
      project: project,
      page_revision: page_revision,
      container_revision: container_revision
    } do
      insert(:publication, project: project, published: yesterday())
      {:ok, view, _html} = live(conn, live_view_publish_route(project.slug))

      assert has_element?(view, "h5", "Publication Details")
      assert has_element?(view, ".badge.badge-secondary.badge-added", "added")
      assert has_element?(view, ".badge.badge-secondary.badge-added", "added")
      assert has_element?(view, "a", page_revision.title)
      assert has_element?(view, "a", container_revision.title)
    end

    test "shows a message when the project has not been published yet", %{
      conn: conn,
      project: project
    } do
      {:ok, view, _html} = live(conn, live_view_publish_route(project.slug))

      assert has_element?(view, "h5", "Publication Details")
      assert has_element?(view, "h6", "This project has not been published yet")
    end

    test "shows versioning details", %{
      conn: conn,
      publication: publication,
      project: project
    } do
      insert(:publication, project: project, published: yesterday())
      {:ok, view, _html} = live(conn, live_view_publish_route(project.slug))
      %{edition: edition, major: major, minor: minor} = publication

      assert has_element?(view, "h5", "Versioning Details")
      assert has_element?(view, "p", "Major")
      assert has_element?(view, "small", Utils.render_version(edition, major, minor))
      assert has_element?(view, "small", Utils.render_version(edition, major + 1, minor))
    end

    test "shows a message when course sections and products will be affected by push forced publication",
         %{
           conn: conn,
           project: project
         } do
      new_publication = insert(:publication, project: project, published: now())
      new_product = insert(:section)

      new_section =
        insert(:section,
          base_project: project,
          type: :enrollable,
          start_date: yesterday(),
          end_date: tomorrow()
        )

      insert(:section_project_publication, %{
        project: project,
        section: new_product,
        publication: new_publication
      })

      insert(:section_project_publication, %{
        project: project,
        section: new_section,
        publication: new_publication
      })

      push_affected = Sections.get_push_force_affected_sections(project.id, new_publication.id)

      {:ok, view, _html} = live(conn, live_view_publish_route(project.slug))

      view
      |> element("input[phx-click=\"force_push\"]")
      |> render_click()

      assert has_element?(view, "li", "#{push_affected.product_count} product(s)")
      assert has_element?(view, "li", "#{push_affected.section_count} course section(s)")
    end

    test "shows a message when course sections and products will not be affected by push forced publication",
         %{
           conn: conn,
           project: project
         } do
      insert(:publication, project: project, published: yesterday())
      {:ok, view, _html} = live(conn, live_view_publish_route(project.slug))

      view
      |> element("input[phx-click=\"force_push\"]")
      |> render_click()

      assert view
             |> element("div.alert.alert-warning")
             |> render() =~
               "This force push update will not affect any product or course section."
    end

    test "shows active course sections information", %{
      conn: conn,
      project: project,
      section1: section1,
      section2: section2
    } do
      {:ok, view, _html} = live(conn, live_view_publish_route(project.slug))

      assert has_element?(view, "h5", "This project has 2 active course sections")
      assert has_element?(view, "#active-course-sections-table")
      assert has_element?(view, "td", section1.title)
      assert has_element?(view, "td", section2.title)
    end

    test "shows message when there are not active course sections", %{
      conn: conn
    } do
      %{project: project} = create_project_with_publication(conn)
      {:ok, view, _html} = live(conn, live_view_publish_route(project.slug))

      assert has_element?(view, "h5", "This project has no active course sections")
    end

    test "open connect to LMS instructions modal", %{
      conn: conn,
      project: project
    } do
      {:ok, view, _html} = live(conn, live_view_publish_route(project.slug))

      view
      |> element("button[phx-click=\"display_lti_connect_modal\"]")
      |> render_click()

      assert has_element?(view, "h4", "Deliver this course through your institution's LMS")
    end

    test "applies sorting", %{
      conn: conn,
      project: project,
      section1: section1,
      section2: section2
    } do
      {:ok, view, _html} = live(conn, live_view_publish_route(project.slug))

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~ section1.title

      view
      |> element("th[phx-click=\"sort\"][phx-value-sort_by=\"title\"]")
      |> render_click(%{sort_by: "title"})

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~ section2.title
    end

    test "applies paging", %{
      conn: conn,
      project: project,
      section1: section1,
      publication: publication
    } do
      last_section =
        Enum.reduce(0..8, [], fn elem, acc ->
          section =
            insert(:section,
              title: "Section#{elem}",
              base_project: project,
              type: :enrollable,
              start_date: yesterday(),
              end_date: tomorrow()
            )

          {:ok, _sr} = Sections.create_section_resources(section, publication)
          acc ++ [section]
        end)
        |> List.last()

      {:ok, view, _html} = live(conn, live_view_publish_route(project.slug))

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~ section1.title

      refute view
             |> element("#active-course-sections-table")
             |> render() =~ last_section.title

      view
      |> element("a[phx-click=\"page_change\"]", "2")
      |> render_click()

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~ last_section.title

      refute view
             |> element("#active-course-sections-table")
             |> render() =~ section1.title
    end

    test "shows info message when a publication is generated successfully", %{
      conn: conn,
      project: project
    } do
      insert(:publication, project: project, published: yesterday())
      {:ok, view, _html} = live(conn, live_view_publish_route(project.slug))

      view
      |> element("form[phx-submit=\"publish_active\"")
      |> render_submit(%{description: "New description"})

      flash = assert_redirected(view, live_view_publish_route(project.slug))
      assert flash["info"] == "Publish Successful!"
    end
  end
end
