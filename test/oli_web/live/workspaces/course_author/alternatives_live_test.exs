defmodule OliWeb.Workspaces.CourseAuthor.AlternativesLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Resources.ResourceType

  defp live_view_alternatives_route(project_slug),
    do: ~p"/workspaces/course_author/#{project_slug}/alternatives"

  describe "alternatives view" do
    setup [:admin_conn, :create_project]

    test "shows only learner preference alternatives", %{conn: conn, project: project} do
      insert_alternatives_group(project, "Decision Point", "upgrade_decision_point")
      insert_alternatives_group(project, "Learner Preference", "user_section_preference")
      insert_alternatives_group(project, "Legacy Alternative", nil)

      {:ok, view, _html} = live(conn, live_view_alternatives_route(project.slug))

      refute has_element?(view, "button", "New A/B Decision Point")
      refute has_element?(view, ".alternatives-group", "Decision Point")
      assert has_element?(view, ".alternatives-group", "Learner Preference")
      assert has_element?(view, ".alternatives-group", "Legacy Alternative")
    end

    test "reorders options, preserves their ids, and keeps the order after reload", %{
      conn: conn,
      project: project,
      admin: admin
    } do
      first = %{"id" => "stable-first", "name" => "First"}
      second = %{"id" => "stable-second", "name" => "Second"}

      group =
        insert_alternatives_group(project, "Ordered Alternatives", nil, [first, second], admin)

      {:ok, view, html} = live(conn, live_view_alternatives_route(project.slug))
      assert_before(html, "First", "Second")

      assert has_element?(
               view,
               "#alternatives-option-#{group.resource_id}-stable-first[phx-hook='DragSource'][draggable='true'][tabindex='0'][phx-keydown='keyboard_reorder_option']"
             )

      refute has_element?(view, "button[phx-click='move_option']")

      assert has_element?(
               view,
               "#option-drop-target-#{group.resource_id}-2[phx-hook='DropTarget'][data-reorder-event='reorder_option']"
             )

      view
      |> element("#alternatives-option-#{group.resource_id}-stable-first")
      |> render_keydown(%{"key" => "ArrowDown", "shiftKey" => true})

      assert_before(render(view), "Second", "First")

      render_hook(view, "reorder_option", %{
        "resourceId" => group.resource_id,
        "optionId" => "stable-second",
        "dropIndex" => 0
      })

      assert_before(render(view), "Second", "First")

      {:ok, _reloaded_view, reloaded_html} =
        live(conn, live_view_alternatives_route(project.slug))

      assert_before(reloaded_html, "Second", "First")
      assert reloaded_html =~ "phx-value-option-id=\"stable-first\""
      assert reloaded_html =~ "phx-value-option-id=\"stable-second\""

      view
      |> render_hook("reorder_option", %{
        "resourceId" => group.resource_id,
        "optionId" => "stable-second",
        "dropIndex" => 2
      })

      assert_before(render(view), "First", "Second")

      render_hook(view, "reorder_option", %{
        "resourceId" => group.resource_id + 99_999,
        "optionId" => "stable-first",
        "dropIndex" => 0
      })

      render_hook(view, "reorder_option", %{
        "resourceId" => "not-an-integer",
        "optionId" => "stable-first",
        "dropIndex" => "also-invalid"
      })

      assert render(view) =~ "Something went wrong. Please refresh the page and try again."
    end
  end

  defp create_project(_conn) do
    insert(:institution)
    project = insert(:project)
    container_resource = insert(:resource)

    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})

    container_revision =
      insert(:revision, %{
        resource: container_resource,
        objectives: %{},
        resource_type_id: ResourceType.id_for_container(),
        children: [],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container"
      })

    publication =
      insert(:publication, %{
        project: project,
        published: nil,
        root_resource_id: container_resource.id
      })

    insert(:published_resource, %{
      publication: publication,
      resource: container_resource,
      revision: container_revision
    })

    [project: project]
  end

  defp insert_alternatives_group(project, title, strategy, options \\ [], author \\ nil) do
    resource = insert(:resource)
    insert(:project_resource, project_id: project.id, resource_id: resource.id)

    revision =
      insert(:revision, %{
        resource: resource,
        author: author,
        resource_type_id: ResourceType.id_for_alternatives(),
        title: title,
        deleted: false,
        content:
          case strategy do
            nil -> %{"options" => options}
            strategy -> %{"strategy" => strategy, "options" => options}
          end
      })

    publication = Oli.Publishing.project_working_publication(project.slug)
    insert(:published_resource, publication: publication, resource: resource, revision: revision)
    revision
  end

  defp assert_before(html, first, second) do
    {first_position, _} = :binary.match(html, first)
    {second_position, _} = :binary.match(html, second)
    assert first_position < second_position
  end
end
