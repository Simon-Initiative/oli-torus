defmodule OliWeb.Admin.CourseSectionVersions.ViewTest do
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  describe "project source" do
    setup [:admin_conn]

    test "renders active base-project sections with end dates, version columns, and links", %{
      conn: conn
    } do
      project = insert(:project, title: "Biology Core", slug: "biology-core")
      remix_project = insert(:project, title: "Lab Manual", slug: "lab-manual")
      other_project = insert(:project, title: "Other Core", slug: "other-core")

      base_publication =
        insert(:publication,
          project: project,
          edition: 1,
          major: 2,
          minor: 3,
          published: ~U[2024-01-01 00:00:00Z]
        )

      latest_base_publication =
        insert(:publication,
          project: project,
          edition: 1,
          major: 2,
          minor: 4,
          published: ~U[2024-02-01 00:00:00Z]
        )

      remix_publication =
        insert(:publication,
          project: remix_project,
          edition: 4,
          major: 5,
          minor: 6,
          published: ~U[2024-03-01 00:00:00Z]
        )

      active_section =
        insert(:section,
          title: "Spring Biology",
          slug: "spring-biology",
          type: :enrollable,
          status: :active,
          base_project: project,
          end_date: ~U[2024-01-01 00:00:00Z]
        )

      active_template =
        insert(:section,
          title: "Biology Template",
          slug: "biology-template",
          type: :blueprint,
          status: :active,
          base_project: project
        )

      no_end_date_section =
        insert(:section,
          title: "Self Paced Biology",
          slug: "self-paced-biology",
          type: :enrollable,
          status: :active,
          base_project: project,
          end_date: nil
        )

      _archived_section =
        insert(:section,
          title: "Archived Biology",
          slug: "archived-biology",
          type: :enrollable,
          status: :archived,
          base_project: project
        )

      remix_only_section =
        insert(:section,
          title: "Remix Only",
          slug: "remix-only",
          type: :enrollable,
          status: :active,
          base_project: other_project
        )

      insert(:section_project_publication,
        section: active_section,
        project: project,
        publication: base_publication
      )

      insert(:section_project_publication,
        section: active_section,
        project: remix_project,
        publication: remix_publication
      )

      insert(:section_project_publication,
        section: active_template,
        project: project,
        publication: latest_base_publication
      )

      insert(:section_project_publication,
        section: no_end_date_section,
        project: project,
        publication: latest_base_publication
      )

      insert(:section_project_publication,
        section: remix_only_section,
        project: project,
        publication: base_publication
      )

      {:ok, view, html} =
        live(conn, ~p"/admin/course_section_versions/#{project.slug}")

      assert view.module == OliWeb.Admin.CourseSectionVersions.View
      assert html =~ "Course Sections / Templates for Biology Core"
      assert html =~ "Spring Biology"
      assert html =~ "Biology Template"
      assert html =~ "Self Paced Biology"
      assert html =~ "Remix Only"
      refute html =~ "Archived Biology"

      assert html =~ "January 1, 2024"
      assert html =~ "No end date"
      assert html =~ "v1.2.3"
      assert html =~ "v1.2.4"
      assert html =~ "v4.5.6"

      assert has_element?(view, "span.badge-danger", "v1.2.3")
      assert has_element?(view, "span.badge-primary", "v1.2.4")
      assert has_element?(view, "td span", "(base project)")
      assert has_element?(view, "td span", "Section")
      assert has_element?(view, "td span", "Template")
      assert has_element?(view, "span.badge-light.text-muted", "N/A")
      assert has_element?(view, "th span.badge-pill.badge-primary", "v1.2.4")
      assert has_element?(view, "th span.badge-pill.badge-primary", "v4.5.6")
      assert has_element?(view, "a[href='/sections/spring-biology/manage']", "Spring Biology")
      assert has_element?(view, "a[href='/sections/remix-only/manage']", "Remix Only")

      assert has_element?(
               view,
               "a[href='/workspaces/course_author/biology-core/overview']",
               "Biology Core"
             )

      assert has_element?(
               view,
               "a[href='/workspaces/course_author/lab-manual/overview']",
               "Lab Manual"
             )

      assert has_element?(
               view,
               "a[href='/workspaces/course_author/other-core/overview']",
               "Other Core"
             )
    end

    test "does not render a header version badge when a source project has no published publication",
         %{
           conn: conn
         } do
      project = insert(:project, title: "Physics Core", slug: "physics-core")

      insert(:section,
        title: "Physics Spring",
        slug: "physics-spring",
        type: :enrollable,
        status: :active,
        base_project: project
      )

      {:ok, view, _html} =
        live(conn, ~p"/admin/course_section_versions/#{project.slug}")

      assert has_element?(
               view,
               "a[href='/workspaces/course_author/physics-core/overview']",
               "Physics Core"
             )

      refute has_element?(view, "th span.badge-pill.badge-primary")
    end

    test "sorts rows by section title, end date, and project version", %{conn: conn} do
      project = insert(:project, title: "History Core", slug: "history-core")

      old_publication =
        insert(:publication,
          project: project,
          edition: 1,
          major: 0,
          minor: 0,
          published: ~U[2024-01-01 00:00:00Z]
        )

      current_publication =
        insert(:publication,
          project: project,
          edition: 2,
          major: 0,
          minor: 0,
          published: ~U[2024-02-01 00:00:00Z]
        )

      current_section =
        insert(:section,
          title: "Current Section",
          slug: "current-section",
          type: :enrollable,
          status: :active,
          base_project: project,
          end_date: ~U[2024-02-01 00:00:00Z]
        )

      old_section =
        insert(:section,
          title: "Old Section",
          slug: "old-section",
          type: :enrollable,
          status: :active,
          base_project: project,
          end_date: ~U[2024-01-01 00:00:00Z]
        )

      _no_version_section =
        insert(:section,
          title: "No Version Section",
          slug: "no-version-section",
          type: :enrollable,
          status: :active,
          base_project: project,
          end_date: nil
        )

      insert(:section_project_publication,
        section: current_section,
        project: project,
        publication: current_publication
      )

      insert(:section_project_publication,
        section: old_section,
        project: project,
        publication: old_publication
      )

      {:ok, view, html} =
        live(conn, ~p"/admin/course_section_versions/#{project.slug}")

      assert_in_order(html, ["Current Section", "No Version Section", "Old Section"])
      assert has_element?(view, "button[phx-value-sort_by='title'] + div", "↑")

      html =
        view
        |> element("button[phx-value-sort_by='title']")
        |> render_click()

      assert_in_order(html, ["Old Section", "No Version Section", "Current Section"])
      assert has_element?(view, "button[phx-value-sort_by='title'] + div", "↓")

      html =
        view
        |> element("button[phx-value-sort_by='end_date']")
        |> render_click()

      assert_in_order(html, ["No Version Section", "Old Section", "Current Section"])
      assert has_element?(view, "button[phx-value-sort_by='end_date'] + div", "↑")

      html =
        view
        |> element("button[phx-value-sort_by='end_date']")
        |> render_click()

      assert_in_order(html, ["Current Section", "Old Section", "No Version Section"])
      assert has_element?(view, "button[phx-value-sort_by='end_date'] + div", "↓")

      html =
        view
        |> element("button[phx-value-sort_by='project:#{project.id}']")
        |> render_click()

      assert_in_order(html, ["No Version Section", "Old Section", "Current Section"])

      html =
        view
        |> element("button[phx-value-sort_by='project:#{project.id}']")
        |> render_click()

      assert_in_order(html, ["Current Section", "Old Section", "No Version Section"])
    end

    test "ignores malformed sort keys without crashing", %{conn: conn} do
      project = insert(:project, title: "Robust Core", slug: "robust-core")

      insert(:section,
        title: "Alpha Section",
        slug: "alpha-section",
        type: :enrollable,
        status: :active,
        base_project: project
      )

      insert(:section,
        title: "Beta Section",
        slug: "beta-section",
        type: :enrollable,
        status: :active,
        base_project: project
      )

      {:ok, view, _html} =
        live(conn, ~p"/admin/course_section_versions/#{project.slug}")

      render_hook(view, "sort", %{"sort_by" => "project:not-an-id"})

      html = render(view)
      assert_in_order(html, ["Alpha Section", "Beta Section"])
      assert has_element?(view, "button[phx-value-sort_by='title'] + div", "↑")
    end
  end

  describe "unknown project" do
    setup [:admin_conn]

    test "renders an error when the project is not found", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/course_section_versions/unknown-project")

      assert html =~ "No matching project was found."
    end
  end

  defp assert_in_order(_html, []), do: :ok

  defp assert_in_order(html, [value | rest]) do
    case String.split(html, value, parts: 2) do
      [_before, after_value] ->
        assert_in_order(after_value, rest)

      [_] ->
        flunk("Expected #{inspect(value)} to appear in order")
    end
  end
end
