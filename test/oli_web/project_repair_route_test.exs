defmodule OliWeb.ProjectRepairRouteTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Oli.Accounts.SystemRole
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Seeder

  @moduletag capture_log: true

  setup do
    # Use a real seeded authoring project so the LiveView mount exercises the
    # normal workspace project assignment hooks and the read-only analysis path.
    seed = Seeder.base_project_with_resource2()

    system_admin =
      author_fixture(%{system_role_id: SystemRole.role_id().system_admin})

    {:ok, Map.put(seed, :system_admin, system_admin)}
  end

  describe "system-admin project repair route" do
    test "allows a system admin to mount the project-scoped tool", %{
      conn: conn,
      project: project,
      system_admin: system_admin
    } do
      conn = log_in_author(conn, system_admin)

      {:ok, view, html} = live(conn, repair_tool_path(project.slug))
      html = html <> render_async(view, 5_000)

      assert html =~ "Project Repair Tool"
      assert has_element?(view, "h2", "Current analysis")
      assert has_element?(view, "h3", "Basic pages scanned")
      assert has_element?(view, "h3", "Pages with repairable shared activities")
    end

    test "requires confirmation before invoking repair and renders the async result", %{
      author: author,
      conn: conn,
      project: project,
      publication: publication,
      system_admin: system_admin
    } do
      # Build the smallest repairable project shape through real authoring seed
      # helpers: two Basic pages reference one resolvable activity. The route test
      # then proves the Phase 5 LiveView wiring reaches the already-covered context
      # repair path without trusting client-supplied ids.
      activity =
        Seeder.create_activity(%{title: "Shared activity"}, publication, project, author)

      Seeder.create_page(
        "Shared page one",
        publication,
        project,
        author,
        activity_reference_content(activity.resource.id)
      )

      Seeder.create_page(
        "Shared page two",
        publication,
        project,
        author,
        activity_reference_content(activity.resource.id)
      )

      conn = log_in_author(conn, system_admin)

      {:ok, view, _html} = live(conn, repair_tool_path(project.slug))
      html = render_async(view, 5_000)

      assert html =~ "Repair shared activity references"
      refute html =~ "Confirm shared activity repair"

      # AC-002/AC-015: confirmation is enforced by the server handler, not only by
      # the button visibility. A forged direct event before confirmation is ignored.
      html = render_click(view, "make_changes", %{})
      refute html =~ "Repair completed"

      assert {:ok, unrepaired_report} =
               Oli.Authoring.ProjectRepair.analyze_project(project, system_admin)

      assert unrepaired_report.summary.repairable_shared_activity_resource_count == 1

      view
      |> element("#project-repair-show-confirmation")
      |> render_click()

      assert has_element?(view, "#project-repair-confirmation")

      view
      |> element("#project-repair-confirm-make-changes")
      |> render_click()

      html = render_async(view, 10_000)

      assert html =~ "Repair completed"
      assert html =~ "Updated 1 pages and cloned 1 activities"

      assert {:ok, report} =
               Oli.Authoring.ProjectRepair.analyze_project(project, system_admin)

      assert report.summary.repairable_shared_activity_resource_count == 0
      assert AuthoringResolver.from_resource_id(project.slug, activity.resource.id)
    end

    test "keeps full shared page count visible when the display list is truncated", %{
      author: author,
      conn: conn,
      project: project,
      publication: publication,
      system_admin: system_admin
    } do
      activity =
        Seeder.create_activity(%{title: "Large shared activity"}, publication, project, author)

      # The LiveView caps per-group page links at 100 to bound diffs, but AC-012
      # still requires the actual page count to remain visible for the group.
      for index <- 1..101 do
        Seeder.create_page(
          "Large shared page #{index}",
          publication,
          project,
          author,
          activity_reference_content(activity.resource.id)
        )
      end

      conn = log_in_author(conn, system_admin)

      {:ok, view, _html} = live(conn, repair_tool_path(project.slug))
      html = render_async(view, 5_000)

      assert html =~ "Referenced by 101 Basic pages"
      assert html =~ "Showing the first 100"
    end

    test "redirects a non-system-admin author before the LiveView mounts", %{
      conn: conn,
      project: project
    } do
      # A normal author may be able to access ordinary project authoring routes,
      # but this repair tool is intentionally gated by the stricter system-admin
      # pipeline before project analysis can run.
      conn = log_in_author(conn, author_fixture())

      assert {:error,
              {:redirect,
               %{
                 flash: %{"error" => "You must be a system admin to access this page."},
                 to: "/workspaces/course_author"
               }}} = live(conn, repair_tool_path(project.slug))
    end
  end

  defp repair_tool_path(project_slug),
    do: ~p"/workspaces/course_author/#{project_slug}/repair_tool"

  defp activity_reference_content(activity_resource_id) do
    %{
      "model" => [
        %{
          "id" => "route-test-group",
          "type" => "group",
          "children" => [
            %{
              "id" => "route-test-activity-reference",
              "type" => "activity-reference",
              "activity_id" => activity_resource_id,
              "children" => []
            }
          ]
        }
      ]
    }
  end
end
