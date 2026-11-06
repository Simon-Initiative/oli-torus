defmodule OliWeb.AnalyticsEventsTest do
  use OliWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Resources.ResourceType
  alias OliWeb.Delivery.Student.Utils

  setup do
    original = Application.fetch_env(:oli, :analytics)
    Application.put_env(:oli, :analytics, gtm_container_id: "GTM-QA123")

    on_exit(fn ->
      case original do
        :error -> Application.delete_env(:oli, :analytics)
        {:ok, value} -> Application.put_env(:oli, :analytics, value)
      end
    end)
  end

  defp analytics_conn(conn) do
    put_connect_params(conn, %{"analytics_enabled" => true, "analytics_context" => nil})
  end

  defp create_course(_context) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    practice =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        title: "Practice page",
        content: %{
          "model" => [
            %{
              "id" => "1",
              "type" => "content",
              "children" => [
                %{"id" => "2", "type" => "p", "children" => [%{"text" => "Practice content"}]}
              ]
            }
          ]
        }
      )

    graded =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        title: "Graded page",
        graded: true,
        max_attempts: 5,
        content: %{"model" => []}
      )

    root =
      insert(:revision,
        resource_type_id: ResourceType.id_for_container(),
        children: [practice.resource_id, graded.resource_id],
        content: %{},
        title: "Root"
      )

    revisions = [practice, graded, root]

    for revision <- revisions do
      insert(:project_resource, %{project_id: project.id, resource_id: revision.resource_id})
    end

    publication = insert(:publication, %{project: project, root_resource_id: root.resource_id})

    for revision <- revisions do
      insert(:published_resource, %{
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: author
      })
    end

    section =
      insert(:section,
        base_project: project,
        open_and_free: true,
        lti_1p3_deployment: nil,
        lti_1p3_deployment_id: nil
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section)

    %{section: section, project: project, practice: practice, graded: graded}
  end

  defp enroll(%{user: user, section: section}) do
    Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
    Sections.mark_section_visited_for_student(section, user)
    :ok
  end

  # The lesson renders its content once the client confirms its scripts loaded.
  defp show_content(view) do
    view |> element("#eventIntercept") |> render_hook("survey_scripts_loaded", %{})
    view
  end

  defp pushed_events(view) do
    %{proxy: {ref, _topic, _pid}} = view
    {:messages, messages} = Process.info(self(), :messages)
    for {^ref, {:push_event, event, payload}} <- messages, do: {event, payload}
  end

  describe "lesson" do
    setup [:user_conn, :create_course, :enroll]

    test "pushes the page context before page_entered, once per mount", %{
      conn: conn,
      section: section,
      project: project,
      practice: practice
    } do
      {:ok, view, _html} =
        live(analytics_conn(conn), Utils.lesson_live_path(section.slug, practice.slug))

      show_content(view)

      render_patch(
        view,
        Utils.lesson_live_path(section.slug, practice.slug, selected_view: :outline)
      )

      events = pushed_events(view) |> Enum.filter(fn {event, _} -> event =~ "analytics" end)

      assert [
               {"analytics:page_view", context},
               {"analytics:track", %{name: "page_entered", params: %{}}}
             ] = events

      assert %{
               page_path: "/sections/:section_slug/lesson/:revision_slug",
               page_area: "delivery",
               user_role: "learner",
               course_id: course_id,
               page_type: "practice",
               entry_point: "direct"
             } = context

      assert course_id == project.id
      refute inspect(events) =~ section.slug
      refute inspect(events) =~ practice.slug
    end

    test "a hard-loaded lesson's head context is already typed, so no second page view is pushed",
         %{conn: conn, section: section, project: project, practice: practice} do
      path = Utils.lesson_live_path(section.slug, practice.slug)
      document = conn |> get(path) |> html_response(200) |> Floki.parse_document!()
      [config] = Floki.attribute(document, "#torus-analytics", "data-config")
      %{"context" => head_context} = Jason.decode!(config)
      course_id = project.id

      assert %{"page_type" => "practice", "course_id" => ^course_id, "user_role" => "learner"} =
               head_context

      conn =
        put_connect_params(conn, %{
          "analytics_enabled" => true,
          "analytics_context" => head_context
        })

      {:ok, view, _html} = live(conn, path)
      show_content(view)

      refute_push_event(view, "analytics:page_view", %{})
      assert_push_event(view, "analytics:track", %{name: "page_entered"})
    end

    test "reports the outline panel only when it opens", %{
      conn: conn,
      section: section,
      practice: practice
    } do
      {:ok, view, _html} =
        live(analytics_conn(conn), Utils.lesson_live_path(section.slug, practice.slug))

      show_content(view)
      assert_push_event(view, "analytics:track", %{name: "page_entered"})

      toggle = ~s{button[data-role='toggle-outline-button'][data-view='desktop']}
      view |> element(toggle) |> render_click()

      assert_push_event(view, "analytics:track", %{
        name: "feature_used",
        params: %{"feature_name" => "outline_opened"}
      })

      render_hook(view, "toggle_outline_sidebar", %{})
      refute_push_event(view, "analytics:track", %{})
    end

    test "reports page_completed when the learner submits a graded page", %{
      conn: conn,
      section: section,
      user: user,
      graded: graded
    } do
      access = insert(:resource_access, user: user, section: section, resource: graded.resource)

      insert(:resource_attempt,
        resource_access: access,
        revision: graded,
        lifecycle_state: :active,
        content: %{"model" => []}
      )

      {:ok, view, _html} =
        live(analytics_conn(conn), Utils.lesson_live_path(section.slug, graded.slug))

      show_content(view)

      assert_push_event(view, "analytics:page_view", %{page_type: "graded"})
      assert_push_event(view, "analytics:track", %{name: "page_entered"})

      assert {:error, {:redirect, _}} =
               view |> element("button[id=submit_answers]") |> render_hook("finalize_attempt")

      assert_push_event(view, "analytics:track", %{name: "page_completed", params: %{}})
    end

    test "nothing is pushed when the deployment has no container", %{
      conn: conn,
      section: section,
      practice: practice
    } do
      Application.put_env(:oli, :analytics, gtm_container_id: nil)

      {:ok, view, _html} =
        live(analytics_conn(conn), Utils.lesson_live_path(section.slug, practice.slug))

      show_content(view)
      render_hook(view, "toggle_outline_sidebar", %{})

      assert pushed_events(view) |> Enum.filter(fn {event, _} -> event =~ "analytics" end) == []
    end
  end

  describe "student navigation" do
    setup [:user_conn, :create_course, :enroll]

    test "Learn search counts once per search, not per refinement", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(analytics_conn(conn), ~p"/sections/#{section.slug}/learn")

      render_hook(view, "search", %{"search_term" => "pra"})
      assert_push_event(view, "analytics:track", %{params: %{"feature_name" => "search_used"}})

      render_hook(view, "search", %{"search_term" => "practice"})
      refute_push_event(view, "analytics:track", %{})

      render_hook(view, "clear_search", %{})
      render_hook(view, "search", %{"search_term" => "graded"})
      assert_push_event(view, "analytics:track", %{params: %{"feature_name" => "search_used"}})
    end

    test "Assignments filter counts changes only", %{conn: conn, section: section} do
      {:ok, view, _html} = live(analytics_conn(conn), ~p"/sections/#{section.slug}/assignments")

      render_hook(view, "select_filter", %{"filter" => "required"})
      assert_push_event(view, "analytics:track", %{params: %{"feature_name" => "filter_used"}})

      render_hook(view, "select_filter", %{"filter" => "required"})
      refute_push_event(view, "analytics:track", %{})
    end
  end

  describe "authoring" do
    setup [:admin_conn]

    test "Publish clicks are reported", %{conn: conn} do
      project = insert(:project)
      container = insert(:resource)

      revision =
        insert(:revision,
          resource: container,
          resource_type_id: ResourceType.id_for_container(),
          children: [],
          content: %{},
          title: "Root"
        )

      insert(:project_resource, %{project_id: project.id, resource_id: container.id})

      publication =
        insert(:publication, project: project, root_resource_id: container.id, published: nil)

      insert(:published_resource,
        publication: publication,
        resource: container,
        revision: revision
      )

      {:ok, view, _html} =
        live(analytics_conn(conn), ~p"/workspaces/course_author/#{project.slug}/publish")

      assert_push_event(view, "analytics:page_view", %{
        page_area: "authoring",
        user_role: "admin",
        course_id: course_id
      })

      assert course_id == project.id

      render_hook(view, "publish_active", %{"publication" => %{"description" => "Notes"}})

      assert_push_event(view, "analytics:track", %{
        name: "feature_used",
        params: %{"feature_name" => "author_publish_clicked"}
      })
    end
  end
end
