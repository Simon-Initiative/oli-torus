defmodule OliWeb.Workspaces.CourseAuthor.PublishLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase
  use Oban.Testing, repo: Oli.Repo

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Delivery.Sections
  alias Oli.Resources.ResourceType
  alias OliWeb.Common.Utils

  @instructor_context_role_id Lti_1p3.Tool.ContextRoles.get_role(:context_instructor).id

  defp live_view_publish_route(project_slug),
    do: ~p"/workspaces/course_author/#{project_slug}/publish"

  defp create_project_and_section(_conn) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    objective_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("objective"),
        title: "Objective 1"
      )

    page_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        content: %{"model" => []},
        objectives: %{
          "1" => [
            objective_1_revision.resource_id
          ]
        },
        title: "revision A",
        ids_added: true
      )

    page_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        content: %{"model" => []},
        title: "revision B",
        ids_added: true
      )

    container_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.id_for_container(),
        children: [page_revision.resource_id, page_2_revision.resource_id],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container"
      })

    all_revisions =
      [
        objective_1_revision,
        page_revision,
        page_2_revision,
        container_revision
      ]

    # asociate resources to project
    Enum.each(all_revisions, fn revision ->
      insert(:project_resource, %{
        project_id: project.id,
        resource_id: revision.resource_id
      })
    end)

    # publish project
    publication =
      insert(:publication, %{
        project: project,
        root_resource_id: container_revision.resource_id,
        published: nil
      })

    # publish resources
    Enum.each(all_revisions, fn revision ->
      insert(:published_resource, %{
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: author
      })
    end)

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
      page_2_revision: page_2_revision,
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
        resource_type_id: ResourceType.id_for_container(),
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
               "You are being <a href=\"/workspaces/course_author\">redirected</a>"
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
               "You are being <a href=\"/workspaces/course_author\">redirected</a>"
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
               "You are being <a href=\"/workspaces/course_author\">redirected</a>"
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
               "You are being <a href=\"/workspaces/course_author\">redirected</a>"
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
        |> assign_current_author(author)
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
      project: project
    } do
      insert(:publication, project: project, published: yesterday())
      {:ok, view, _html} = live(conn, live_view_publish_route(project.slug))

      assert has_element?(view, "h5", "Publication Details")

      assert view
             |> element(".publish_changes_table tr:first-child > td:first-child")
             |> render() =~ "Objective 1"

      assert view
             |> element(".publish_changes_table tr:last-child > td:first-child")
             |> render() =~ "revision B"

      assert view
             |> element(
               ".publish_changes_table tr:first-child > td:nth-child(2) .badge.badge-added"
             )
             |> render() =~ "added"

      assert view
             |> element(
               ".publish_changes_table tr:last-child > td:nth-child(2) .badge.badge-added"
             )
             |> render() =~ "added"

      assert view
             |> element(".publish_changes_table tr:first-child > td:nth-child(3)")
             |> render() =~ "Minor"

      assert view
             |> element(".publish_changes_table tr:last-child > td:nth-child(3)")
             |> render() =~ "Minor"
    end

    test "applies sorting to publication details table", %{
      conn: conn,
      project: project
    } do
      insert(:publication, project: project, published: yesterday())
      {:ok, view, _html} = live(conn, live_view_publish_route(project.slug))

      assert view
             |> element(".publish_changes_table tr:first-child > td:first-child")
             |> render() =~ "Objective 1"

      assert view
             |> element(".publish_changes_table tr:last-child > td:first-child")
             |> render() =~ "revision B"

      view
      |> element(".publish_changes_table th[phx-value-sort_by=\"title\"]", "Title")
      |> render_click(%{sort_by: "title"})

      assert view
             |> element(".publish_changes_table tr:first-child > td:first-child")
             |> render() =~ "revision B"

      assert view
             |> element(".publish_changes_table tr:last-child > td:first-child")
             |> render() =~ "Objective 1"
    end

    test "applies paging to publication details table", %{
      conn: conn,
      project: project,
      container_revision: container_revision,
      author: author
    } do
      publication = insert(:publication, project: project, published: yesterday())

      last_revision =
        Enum.reduce(0..9, [], fn elem, acc ->
          page_resource = insert(:resource)

          page_revision =
            insert(:revision,
              resource: page_resource,
              resource_type_id: ResourceType.id_for_page(),
              content: %{"model" => []},
              title: "revision#{elem}",
              ids_added: true
            )

          insert(:project_resource, %{project_id: project.id, resource_id: page_resource.id})

          insert(:published_resource, %{
            publication: publication,
            resource: page_resource,
            revision: page_revision,
            author: author
          })

          acc ++ [page_revision]
        end)
        |> List.last()

      {:ok, view, _html} = live(conn, live_view_publish_route(project.slug))

      assert view
             |> element(".publish_changes_table tr:first-child > td:first-child")
             |> render() =~ "Objective 1"

      refute view
             |> element(".publish_changes_table tr:last-child > td:first-child")
             |> render() =~ last_revision.title

      view
      |> element("#publish-changes-table button", "2")
      |> render_click()

      refute view
             |> element(".publish_changes_table tr:first-child > td:first-child")
             |> render() =~ container_revision.title

      assert view
             |> element(".publish_changes_table tr:last-child > td:first-child")
             |> render() =~ last_revision.title
    end

    test "renders creator and instructors content in the table", ctx do
      # Instructors
      instructor_1 =
        insert(:user, name: "Mr John Hugo Doe", given_name: "John", family_name: "Doe")

      instructor_2 =
        insert(:user, name: "Ms Jane Marie Doe", given_name: "Jane", family_name: "Doe")

      # Enrollments
      now = DateTime.utc_now()
      min_after = DateTime.add(now, 1, :minute)

      enrollment_1 =
        insert(:enrollment, section: ctx.section1, user: instructor_1, inserted_at: now)

      enrollment_2 =
        insert(:enrollment, section: ctx.section1, user: instructor_2, inserted_at: min_after)

      enrollment_3 =
        insert(:enrollment, section: ctx.section2, user: instructor_2, inserted_at: now)

      Oli.Repo.insert_all("enrollments_context_roles", [
        [enrollment_id: enrollment_1.id, context_role_id: @instructor_context_role_id],
        [enrollment_id: enrollment_2.id, context_role_id: @instructor_context_role_id],
        [enrollment_id: enrollment_3.id, context_role_id: @instructor_context_role_id]
      ])

      # Calling endpoint
      {:ok, _view, html} = live(ctx.conn, live_view_publish_route(ctx.project.slug))

      # Checking header titles
      assert [
               "Title",
               "Current Publication",
               "Creator",
               "Instructors",
               "Relationship Type",
               "Start Date",
               "End Date"
             ] ==
               html
               |> Floki.find("#active-course-sections-table thead tr > th")
               |> Enum.map(&text/1)

      [row_1, row_2] = Floki.find(html, "#active-course-sections-table tbody > tr ")
      [_, _, row_1_creator, row_1_instructors | _rest] = Floki.find(row_1, "td > div")

      # Checking creator and instructors for section 1
      assert text(row_1_creator) =~ Utils.name(instructor_1)
      # There are 2 instructors enrolled in section 1 -the creator plus another instructor
      assert text(row_1_instructors) =~ "#{Utils.name(instructor_1)}; #{Utils.name(instructor_2)}"

      # Checking creator and instructors for section 2
      [_, _, row_2_creator, row_2_instructors | _rest] = Floki.find(row_2, "td > div")

      assert text(row_2_creator) =~ Utils.name(instructor_2)
      # There is only one instructor enrolled in section 1 --the creator
      assert text(row_2_instructors) =~ Utils.name(instructor_2)
    end

    defp text(html), do: String.trim(Floki.text(html))

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
      |> element("form#versioning-details-form")
      |> render_change(%{
        "publication" => %{"auto_push_update" => "true", "description" => "some description"}
      })

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
      |> element("form#versioning-details-form")
      |> render_change(%{
        "publication" => %{"auto_push_update" => "true", "description" => "some description"}
      })

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
      |> element("button[phx-click=\"page_change\"]", "2")
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

      view
      |> element("button", "Ok")
      |> render_click()

      flash = assert_redirected(view, live_view_publish_route(project.slug))
      assert flash["info"] == "Publish Successful!"
    end

    test "enques an embedding Oban job for each PAGE revision when publishing if the calculate_embeddings_on_publish attribute is enabled",
         %{
           conn: conn,
           project: project,
           publication: publication,
           page_revision: page_revision,
           page_2_revision: page_2_revision
         } do
      Oli.Authoring.Course.update_project(project, %{
        attributes: %{calculate_embeddings_on_publish: true}
      })

      {:ok, view, _html} = live(conn, live_view_publish_route(project.slug))

      view
      |> element("form[phx-submit=\"publish_active\"")
      |> render_submit(%{description: "New description"})

      view
      |> element("button", "Ok")
      |> render_click()

      # Two jobs are enqueued (only page revisions are considered, the objective revision is ignored)
      assert_enqueued(
        worker: Oli.Search.EmbeddingWorker,
        args: %{"publication_id" => publication.id, "revision_id" => page_revision.id}
      )

      assert_enqueued(
        worker: Oli.Search.EmbeddingWorker,
        args: %{"publication_id" => publication.id, "revision_id" => page_2_revision.id}
      )

      enqueued_jobs = all_enqueued(worker: Oli.Search.EmbeddingWorker)

      assert length(enqueued_jobs) == 2
    end

    test "does NOT calculates the embeddings if calculate_embeddings_on_publish attribute is disabled",
         %{
           conn: conn,
           project: project,
           publication: publication,
           page_revision: page_revision,
           page_2_revision: page_2_revision
         } do
      Oli.Authoring.Course.update_project(project, %{
        attributes: %{calculate_embeddings_on_publish: false}
      })

      {:ok, view, _html} = live(conn, live_view_publish_route(project.slug))

      view
      |> element("form[phx-submit=\"publish_active\"")
      |> render_submit(%{description: "New description"})

      view
      |> element("button", "Ok")
      |> render_click()

      # No jobs are enqueued
      refute_enqueued(
        worker: Oli.Search.EmbeddingWorker,
        args: %{"publication_id" => publication.id, "revision_id" => page_revision.id}
      )

      refute_enqueued(
        worker: Oli.Search.EmbeddingWorker,
        args: %{"publication_id" => publication.id, "revision_id" => page_2_revision.id}
      )

      enqueued_jobs = all_enqueued(worker: Oli.Search.EmbeddingWorker)

      assert length(enqueued_jobs) == 0
    end

    test "renders header", %{conn: conn, project: project} do
      {:ok, view, _html} = live(conn, live_view_publish_route(project.slug))

      assert view
             |> element("#header_id")
             |> render() =~
               "Publish"
    end
  end
end
