defmodule OliWeb.Workspaces.CourseAuthor.ObjectivesLiveTest do
  use OliWeb.ConnCase

  # Phase 4 requirements proof map:
  # AC-001/AC-002 -> summary rendering and mutation-refresh tests exercise parent
  #                     and Sub-Objective row shaping.
  # AC-003/AC-004/AC-005 -> independent expansion, bucket filtering, page-first,
  #                          and page-empty-state tests.
  # AC-006/AC-007 -> read-only page/activity href and no-phx-click assertions.
  # AC-008 -> icon roles, responsive overflow classes, and loading/empty/error
  #            state assertions.
  # AC-009 -> explicit ARIA state, keyboard-native buttons, and focus classes.
  # AC-010 -> banked activity fixture proves the UI renders no banked activity.
  # AC-011 -> ObjectiveCoverage contract tests plus this LiveView's single model
  #            refresh path prove the workspace has no competing query path.

  import Oli.Factory
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Oli.Authoring.Editing.ObjectiveEditor
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources.ResourceType

  defp live_view_route(project_slug, params \\ %{}),
    do: ~p"/workspaces/course_author/#{project_slug}/objectives?#{params}"

  defp wait_for_coverage(view) do
    wait_until(fn -> has_element?(view, "#objective-coverage-ready") end)
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
        resource_type_id: ResourceType.id_for_container(),
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

  defp create_objective(project, publication, slug, title, children \\ []) do
    # Create objective
    obj_resource = insert(:resource)

    obj_revision =
      insert(:revision, %{
        resource: obj_resource,
        objectives: %{},
        resource_type_id: ResourceType.id_for_objective(),
        children: children,
        content: %{},
        deleted: false,
        slug: slug,
        title: title
      })

    # Associate objective to the project
    insert(:project_resource, %{project_id: project.id, resource_id: obj_resource.id})
    # Publish objective resource
    insert(:published_resource, %{
      author: hd(project.authors),
      publication: publication,
      resource: obj_resource,
      revision: obj_revision
    })

    {:ok, obj_revision}
  end

  defp create_page_with_objective(
         project,
         publication,
         objectives,
         slug \\ "slug",
         activity_refs \\ [],
         graded \\ false
       ) do
    # Create page
    page_resource = insert(:resource)

    page_revision =
      insert(:revision, %{
        objectives: %{"attached" => objectives},
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
        resource_type_id: ResourceType.id_for_page(),
        children: [],
        activity_refs: activity_refs,
        graded: graded,
        content: %{"model" => []},
        deleted: false,
        title: "Page 1",
        resource: page_resource,
        slug: slug
      })

    # Associate page to the project
    insert(:project_resource, %{project_id: project.id, resource_id: page_resource.id})
    # Publish page resource
    insert(:published_resource, %{
      author: hd(project.authors),
      publication: publication,
      resource: page_resource,
      revision: page_revision
    })

    {:ok, page_revision}
  end

  defp create_embedded_activity_with_objective(
         project,
         publication,
         objective_id,
         slug,
         scope \\ :embedded
       ) do
    activity_resource = insert(:resource)

    activity_revision =
      insert(:revision, %{
        resource: activity_resource,
        objectives: %{"1" => [objective_id]},
        resource_type_id: ResourceType.id_for_activity(),
        children: [],
        content: %{},
        deleted: false,
        title: "Activity",
        slug: slug,
        scope: scope
      })

    insert(:project_resource, %{project_id: project.id, resource_id: activity_resource.id})

    published_resource =
      insert(:published_resource, %{
        author: hd(project.authors),
        publication: publication,
        resource: activity_resource,
        revision: activity_revision
      })

    {:ok, _} =
      Oli.Publishing.update_published_resource(published_resource, %{
        locked_by_id: nil,
        lock_updated_at: nil
      })

    {:ok, activity_revision}
  end

  describe "user cannot access when is not logged in" do
    setup [:create_project]

    test "redirects to new session when accessing the objectives view", %{
      conn: conn,
      project: project
    } do
      redirect_path =
        "/authors/log_in"

      {:error, {:redirect, %{to: ^redirect_path}}} = live(conn, live_view_route(project.slug))
    end
  end

  describe "user cannot access when is logged in as an author but is not an author of the project" do
    setup [:author_conn, :create_project]

    test "redirects to projects view when accessing the objectives view", %{
      conn: conn,
      project: project
    } do
      redirect_path = "/workspaces/course_author"

      {:error, {:redirect, %{to: ^redirect_path}}} = live(conn, live_view_route(project.slug))
    end
  end

  describe "objectives" do
    setup [:admin_conn, :create_project]

    test "loads correctly when there are no objectives", %{conn: conn, project: project} do
      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      assert has_element?(view, "#objectives-table")
      assert has_element?(view, "input[phx-change='change_search'][phx-blur='apply_search']")
      assert has_element?(view, "#select_sort")
      assert has_element?(view, "button[phx-click='display_new_modal']", "New Objective")

      assert has_element?(
               view,
               "p.text-Text-text-high",
               "Learning objectives help you to organize course content and determine appropriate assessments and instructional strategies."
             )

      assert has_element?(
               view,
               "p",
               "Learning objectives help you to organize course content and determine appropriate assessments and instructional strategies."
             )

      assert has_element?(
               view,
               ~s|a[href="https://www.cmu.edu/teaching/designteach/design/learningobjectives.html"][rel="noopener"][target="_blank"]|,
               "CMU Eberly Center guide on learning objectives"
             )

      assert has_element?(
               view,
               "p",
               "to learn more about the importance of attaching learning objectives to pages and activities."
             )

      assert has_element?(view, "p", "None exist")

      wait_for_coverage(view)
    end

    test "ignores stale coverage results", %{
      conn: conn,
      project: project,
      publication: publication
    } do
      {:ok, objective} = create_objective(project, publication, "obj", "Objective")
      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      wait_for_coverage(view)
      send(view.pid, {:objective_coverage_loaded, make_ref(), {:error, :project_not_found}})

      wait_until(fn -> has_element?(view, "#objective-coverage-ready") end)
      assert has_element?(view, "##{objective.slug}")
      assert has_element?(view, "#objective-summary-#{objective.resource_id}")
      refute has_element?(view, "#objective-coverage-error")
    end

    test "renders a generic error for an unexpected coverage failure", %{
      conn: conn,
      project: project
    } do
      {:ok, view, _html} = live(conn, live_view_route(project.slug))
      load_ref = :sys.get_state(view.pid).socket.assigns.coverage_load_ref

      send(view.pid, {:objective_coverage_loaded, load_ref, {:error, :coverage_load_failed}})

      assert has_element?(
               view,
               "#objective-coverage-error",
               "Objective coverage could not be loaded."
             )

      refute has_element?(view, "#objective-coverage-ready")
    end

    test "applies searching", %{conn: conn, project: project, publication: publication} do
      {:ok, first_obj} = create_objective(project, publication, "first_obj", "First Objective")
      {:ok, second_obj} = create_objective(project, publication, "second_obj", "Second Objective")

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      assert has_element?(view, "#objectives-table")
      assert has_element?(view, "##{first_obj.slug}")
      assert has_element?(view, "##{second_obj.slug}")

      view
      |> element("input[phx-change=\"change_search\"]")
      |> render_change(%{value: "first"})

      view
      |> element("input[phx-blur=\"apply_search\"]")
      |> render_blur(%{value: "first"})

      assert has_element?(view, "##{first_obj.slug}")
      refute has_element?(view, "##{second_obj.slug}")

      view
      |> element("button[phx-click='reset_search']")
      |> render_click()

      assert has_element?(view, "##{first_obj.slug}")
      assert has_element?(view, "##{second_obj.slug}")

      wait_for_coverage(view)
    end

    test "applies sorting", %{conn: conn, project: project, publication: publication} do
      {:ok, _first_obj} = create_objective(project, publication, "first_obj", "First Objective")

      {:ok, _second_obj} =
        create_objective(project, publication, "second_obj", "Second Objective")

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      assert view
             |> element("#accordion article:first-child")
             |> render() =~
               "First Objective"

      view
      |> element("form[phx-change='sort']")
      |> render_change(%{sort_by: "title"})

      assert view
             |> element("#accordion article:first-child")
             |> render() =~
               "Second Objective"

      wait_for_coverage(view)
    end

    test "applies paging", %{conn: conn, project: project, publication: publication} do
      [first_obj | _tail] =
        1..21
        |> Enum.to_list()
        |> Enum.map(fn i ->
          create_objective(project, publication, "#{i}_obj", "#{i} Objective") |> elem(1)
        end)
        |> Enum.sort_by(& &1.title)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))
      wait_for_coverage(view)

      assert has_element?(view, "##{first_obj.slug}")

      view
      |> element(
        "#header_paging > nav > ul > li:nth-child(4) > button",
        "2"
      )
      |> render_click()

      refute has_element?(view, "##{first_obj.slug}")
      assert has_element?(view, "#accordion article:first-child", "LO 21")

      wait_for_coverage(view)
    end

    test "show objective", %{conn: conn, project: project, publication: publication} do
      {:ok, sub_obj} = create_objective(project, publication, "sub_obj", "Sub Objective")
      {:ok, sub_obj_2} = create_objective(project, publication, "sub_obj_2", "Sub Objective 2")

      {:ok, obj} =
        create_objective(project, publication, "obj", "Objective", [
          sub_obj.resource_id,
          sub_obj_2.resource_id
        ])

      {:ok, _page_1} =
        create_page_with_objective(project, publication, [obj.resource_id], "other_slug")

      {:ok, _page_2} =
        create_page_with_objective(project, publication, [
          sub_obj.resource_id,
          sub_obj_2.resource_id
        ])

      {:ok, view, _html} = live(conn, live_view_route(project.slug, %{selected: obj.slug}))

      assert has_element?(view, "##{obj.slug}")
      refute has_element?(view, "#objective-summary-#{obj.resource_id}")
      assert has_element?(view, ".collapse", "Sub-Objectives")
      assert has_element?(view, ".collapse", "#{sub_obj.title}")
      refute has_element?(view, ".collapse", "Pages")

      wait_for_coverage(view)
    end

    test "maps parent summaries from descendant coverage and child details from direct coverage",
         %{
           conn: conn,
           project: project,
           publication: publication
         } do
      {:ok, child} = create_objective(project, publication, "child", "Child Objective")

      {:ok, parent} =
        create_objective(project, publication, "parent", "Parent Objective", [child.resource_id])

      {:ok, formative_activity} =
        create_embedded_activity_with_objective(
          project,
          publication,
          child.resource_id,
          "formative-child-activity"
        )

      {:ok, summative_activity} =
        create_embedded_activity_with_objective(
          project,
          publication,
          child.resource_id,
          "summative-child-activity"
        )

      {:ok, formative_page} =
        create_page_with_objective(
          project,
          publication,
          [child.resource_id],
          "formative-child-page",
          [formative_activity.resource_id]
        )

      {:ok, summative_page} =
        create_page_with_objective(
          project,
          publication,
          [child.resource_id],
          "summative-child-page",
          [summative_activity.resource_id],
          true
        )

      {:ok, view, _html} = live(conn, live_view_route(project.slug, %{selected: parent.slug}))
      wait_for_coverage(view)

      refute has_element?(view, "#objective-summary-#{parent.resource_id}")

      assert has_element?(
               view,
               "#sub-objective-summary-#{parent.slug}-#{child.resource_id} [aria-label='1 formative activities']"
             )

      assert has_element?(
               view,
               "#sub-objective-summary-#{parent.slug}-#{child.resource_id} [aria-label='1 summative activities']"
             )

      view
      |> element("button[phx-click='toggle_objective'][phx-value-slug=#{child.slug}]")
      |> render_click()

      assert has_element?(
               view,
               "#sub-objective-coverage-#{child.resource_id}",
               formative_page.title
             )

      assert has_element?(
               view,
               "#sub-objective-coverage-#{child.resource_id}",
               summative_page.title
             )

      assert has_element?(
               view,
               "#sub-objective-summary-#{parent.slug}-#{child.resource_id}"
             )
    end

    test "expands and collapses objectives independently", %{
      conn: conn,
      project: project,
      publication: publication
    } do
      {:ok, sub_obj_a} = create_objective(project, publication, "sub_obj_a", "Sub Objective A")
      {:ok, sub_obj_b} = create_objective(project, publication, "sub_obj_b", "Sub Objective B")

      {:ok, obj_a} =
        create_objective(project, publication, "obj_a", "Objective A", [sub_obj_a.resource_id])

      {:ok, obj_b} =
        create_objective(project, publication, "obj_b", "Objective B", [sub_obj_b.resource_id])

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      wait_for_coverage(view)

      view
      |> element("button[phx-click='toggle_objective'][phx-value-slug=#{obj_a.slug}]")
      |> render_click(%{"slug" => obj_a.slug})

      assert has_element?(view, "##{obj_a.slug} .collapse", "#{sub_obj_a.title}")

      assert has_element?(
               view,
               "##{obj_a.slug} button[phx-value-slug=#{sub_obj_a.slug}][disabled]"
             )

      refute has_element?(
               view,
               "#sub-objective-chevron-#{obj_a.slug}-#{sub_obj_a.resource_id} svg"
             )

      refute has_element?(view, "##{obj_b.slug} .collapse", "#{sub_obj_b.title}")

      view
      |> element("button[phx-click='toggle_objective'][phx-value-slug=#{obj_b.slug}]")
      |> render_click(%{"slug" => obj_b.slug})

      assert has_element?(view, "##{obj_a.slug} .collapse", "#{sub_obj_a.title}")
      assert has_element?(view, "##{obj_b.slug} .collapse", "#{sub_obj_b.title}")

      view
      |> element("button[phx-click='toggle_objective'][phx-value-slug=#{obj_a.slug}]")
      |> render_click(%{"slug" => obj_a.slug})

      refute has_element?(view, "##{obj_a.slug} .collapse", "#{sub_obj_a.title}")
      assert has_element?(view, "##{obj_b.slug} .collapse", "#{sub_obj_b.title}")
    end

    test "persists expanded objectives in the URL", %{
      conn: conn,
      project: project,
      publication: publication
    } do
      {:ok, sub_obj_a} = create_objective(project, publication, "sub_obj_a", "Sub Objective A")
      {:ok, sub_obj_b} = create_objective(project, publication, "sub_obj_b", "Sub Objective B")

      {:ok, obj_a} =
        create_objective(project, publication, "obj_a", "Objective A", [sub_obj_a.resource_id])

      {:ok, obj_b} =
        create_objective(project, publication, "obj_b", "Objective B", [sub_obj_b.resource_id])

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      wait_for_coverage(view)

      view
      |> element("button[phx-click='toggle_objective'][phx-value-slug=#{obj_a.slug}]")
      |> render_click(%{"slug" => obj_a.slug})

      assert assert_patch(view) =~ "expanded=#{obj_a.slug}"

      view
      |> element("button[phx-click='toggle_objective'][phx-value-slug=#{obj_b.slug}]")
      |> render_click(%{"slug" => obj_b.slug})

      expanded = Enum.sort([obj_a.slug, obj_b.slug]) |> Enum.join(",")

      assert view |> assert_patch() |> URI.decode() =~ "expanded=#{expanded}"

      view
      |> element("form[phx-change='sort']")
      |> render_change(%{sort_by: "title"})

      assert view |> assert_patch() |> URI.decode() =~ "expanded=#{expanded}"

      {:ok, expanded_view, _html} =
        live(conn, live_view_route(project.slug, %{expanded: expanded}))

      wait_for_coverage(expanded_view)

      assert has_element?(expanded_view, "##{obj_a.slug} .collapse", "#{sub_obj_a.title}")
      assert has_element?(expanded_view, "##{obj_b.slug} .collapse", "#{sub_obj_b.title}")

      wait_for_coverage(view)
    end

    test "new objective", %{conn: conn, project: project} do
      title = "New Objective"

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      refute has_element?(view, "#{title}")

      view
      |> element("button[phx-click='display_new_modal']")
      |> render_click(%{})

      view
      |> element("form[phx-submit='new']")
      |> render_submit(%{"revision" => %{"title" => title, "parent_slug" => ""}})

      assert view
             |> element(~s{div[role="alert"].alert-info})
             |> render() =~
               "Objective successfully created"

      [%{revision: revision} | _tail] = ObjectiveEditor.fetch_objective_mappings(project)

      assert has_element?(view, "##{revision.slug}")
      assert has_element?(view, "button[phx-value-slug=#{revision.slug}]", "#{revision.title}")

      wait_for_coverage(view)
    end

    test "edit objective", %{conn: conn, project: project, publication: publication} do
      title = "New title"
      {:ok, obj} = create_objective(project, publication, "obj", "Objective")

      {:ok, view, _html} = live(conn, live_view_route(project.slug, %{selected: obj.slug}))

      assert has_element?(view, "##{obj.slug}")
      assert has_element?(view, "button[phx-value-slug=#{obj.slug}]", "#{obj.title}")

      view
      |> element("button[phx-click='display_edit_modal']")
      |> render_click(%{"slug" => obj.slug})

      view
      |> element("form[phx-submit='edit']")
      |> render_submit(%{"revision" => %{"title" => title, "slug" => obj.slug}})

      assert view
             |> element(~s{div[role="alert"].alert-info})
             |> render() =~
               "Objective successfully updated"

      [%{revision: new_obj} | _tail] = ObjectiveEditor.fetch_objective_mappings(project)

      refute has_element?(view, "button[phx-value-slug=#{obj.slug}]", "#{obj.title}")
      assert has_element?(view, "button[phx-value-slug=#{new_obj.slug}]", "#{title}")

      wait_for_coverage(view)
    end

    test "remove objective", %{conn: conn, project: project, publication: publication} do
      {:ok, sub_obj} = create_objective(project, publication, "sub_obj", "Sub Objective")

      {:ok, obj_a} =
        create_objective(project, publication, "obj_a", "Objective A", [sub_obj.resource_id])

      {:ok, obj_b} = create_objective(project, publication, "obj_b", "Objective B")
      {:ok, page} = create_page_with_objective(project, publication, [obj_b.resource_id])

      removal_title = "Objective C"
      {:ok, obj_c} = create_objective(project, publication, "obj_c", removal_title)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      view
      |> element("button[phx-click='toggle_objective'][phx-value-slug=#{obj_a.slug}]")
      |> render_click(%{"slug" => obj_a.slug})

      view
      |> element("button[phx-click='display_delete_modal'][phx-value-slug=#{obj_a.slug}]")
      |> render_click(%{"slug" => obj_a.slug})

      assert view
             |> element(~s(div[role="alert"].alert-danger))
             |> render() =~
               "Could not remove objective if it has sub-objectives associated"

      view
      |> element("button[phx-click='toggle_objective'][phx-value-slug=#{obj_b.slug}]")
      |> render_click(%{"slug" => obj_b.slug})

      view
      |> element("button[phx-click='display_delete_modal'][phx-value-slug=#{obj_b.slug}]")
      |> render_click(%{"slug" => obj_b.slug})

      assert has_element?(
               view,
               "#delete_objective_modal",
               "Deleting this objective is"
             )

      assert has_element?(
               view,
               "#delete_objective_modal strong",
               "blocked"
             )

      assert has_element?(
               view,
               "#delete_objective_modal",
               "attached to it are currently being edited"
             )

      assert has_element?(view, "#delete_objective_modal", "Page")
      assert has_element?(view, "#delete_objective_modal", "#{page.title}")

      view
      |> element("button[phx-click='toggle_objective'][phx-value-slug=#{obj_c.slug}]")
      |> render_click(%{"slug" => obj_c.slug})

      view
      |> element("button[phx-click='display_delete_modal'][phx-value-slug=#{obj_c.slug}]")
      |> render_click(%{"slug" => obj_c.slug})

      view
      |> element("button[phx-click='delete'][phx-value-slug=#{obj_c.slug}]")
      |> render_click(%{"slug" => obj_c.slug, "parent_slug" => ""})

      assert view
             |> element(~s{div[role="alert"].alert-info})
             |> render() =~
               "Objective successfully removed"

      assert 3 ==
               project
               |> ObjectiveEditor.fetch_objective_mappings()
               |> length()

      refute has_element?(view, "##{obj_c.slug}")

      wait_for_coverage(view)
    end

    test "remove objective with orphaned embedded activity attachment", %{
      conn: conn,
      project: project,
      publication: publication
    } do
      {:ok, obj} = create_objective(project, publication, "obj_a", "Objective A")

      {:ok, activity} =
        create_embedded_activity_with_objective(
          project,
          publication,
          obj.resource_id,
          "orphaned_activity"
        )

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      view
      |> element("button[phx-click='toggle_objective'][phx-value-slug=#{obj.slug}]")
      |> render_click(%{"slug" => obj.slug})

      view
      |> element("button[phx-click='display_delete_modal'][phx-value-slug=#{obj.slug}]")
      |> render_click(%{"slug" => obj.slug})

      assert has_element?(view, "#delete_objective_modal", "Delete Objective")

      view
      |> element("button[phx-click='delete'][phx-value-slug=#{obj.slug}]")
      |> render_click(%{"slug" => obj.slug, "parent_slug" => ""})

      assert view
             |> element(~s{div[role="alert"].alert-info})
             |> render() =~
               "Objective successfully removed"

      updated_activity = AuthoringResolver.from_resource_id(project.slug, activity.resource_id)

      refute updated_activity.objectives
             |> Map.values()
             |> List.flatten()
             |> Enum.member?(obj.resource_id)
    end

    test "add existing sub objective", %{conn: conn, project: project, publication: publication} do
      {:ok, sub_obj_a} = create_objective(project, publication, "sub_obj_a", "Sub Objective A")

      {:ok, sub_obj_b} =
        create_objective(project, publication, "sub_obj_b", "Testing Sub Objective B")

      {:ok, sub_obj_c} = create_objective(project, publication, "sub_obj_c", "Sub Objective C")

      {:ok, first_obj} =
        create_objective(project, publication, "first_obj", "Objective 1", [sub_obj_a.resource_id])

      {:ok, _second_obj} =
        create_objective(project, publication, "second_obj", "Objective 2", [
          sub_obj_b.resource_id,
          sub_obj_c.resource_id
        ])

      {:ok, view, _html} = live(conn, live_view_route(project.slug, %{selected: first_obj.slug}))

      refute has_element?(view, "button", "Create new Sub-Objective")
      refute has_element?(view, "button", "Add existing Sub-Objective")
      assert has_element?(view, "button", "Add Existing")
      assert has_element?(view, "button", "Create New")
      refute has_element?(view, "##{first_obj.slug} .collapse", "#{sub_obj_b.title}")

      view
      |> element(
        "button[phx-click='display_add_existing_sub_modal'][phx-value-slug=#{first_obj.slug}]",
        "Add Existing"
      )
      |> render_click(%{"slug" => first_obj.slug})

      refute has_element?(
               view,
               "button[phx-click='add_existing_sub'][phx-value-slug=#{sub_obj_a.slug}]",
               "Add"
             )

      assert has_element?(
               view,
               "button[phx-click='add_existing_sub'][phx-value-slug=#{sub_obj_b.slug}]",
               "Add"
             )

      assert has_element?(
               view,
               "button[phx-click='add_existing_sub'][phx-value-slug=#{sub_obj_c.slug}]",
               "Add"
             )

      view
      |> element("#select_existing_sub_modal #text-search-input")
      |> render_hook("text_search_change", %{value: "testing"})

      assert has_element?(
               view,
               "button[phx-click='add_existing_sub'][phx-value-slug=#{sub_obj_b.slug}]",
               "Add"
             )

      refute has_element?(
               view,
               "button[phx-click='add_existing_sub'][phx-value-slug=#{sub_obj_c.slug}]",
               "Add"
             )

      view
      |> element(
        "button[phx-click='add_existing_sub'][phx-value-slug=#{sub_obj_b.slug}]",
        "Add"
      )
      |> render_click(%{"slug" => sub_obj_b.slug, "parent_slug" => first_obj.slug})

      assert has_element?(view, ".collapse", "#{sub_obj_b.title}")
      assert has_element?(view, ".collapse", "#{sub_obj_b.title}")

      assert view
             |> element(~s{div[role="alert"].alert-info})
             |> render() =~
               "Sub-objective successfully added"

      assert 5 ==
               project
               |> ObjectiveEditor.fetch_objective_mappings()
               |> length()

      wait_for_coverage(view)
    end

    test "new sub objective", %{conn: conn, project: project, publication: publication} do
      title = "Sub Objective"
      {:ok, obj} = create_objective(project, publication, "obj", "Objective")

      {:ok, view, _html} = live(conn, live_view_route(project.slug, %{selected: obj.slug}))

      refute has_element?(view, "button", "Create new Sub-Objective")
      refute has_element?(view, "button", "Add existing Sub-Objective")
      assert has_element?(view, "button", "Create New")

      view
      |> element(
        "button[phx-click='display_new_sub_modal'][phx-value-slug=#{obj.slug}]",
        "Create New"
      )
      |> render_click(%{slug: obj.slug})

      view
      |> element("form[phx-submit='new']")
      |> render_submit(%{"revision" => %{"title" => title, "parent_slug" => obj.slug}})

      assert view
             |> element(~s{div[role="alert"].alert-info})
             |> render() =~
               "Objective successfully created"

      assert 2 ==
               project
               |> ObjectiveEditor.fetch_objective_mappings()
               |> length()

      assert has_element?(view, ".collapse", "#{title}")

      wait_for_coverage(view)
    end

    test "edit sub objective", %{conn: conn, project: project, publication: publication} do
      title = "New title"
      {:ok, sub_obj} = create_objective(project, publication, "sub_obj", "Sub Objective")

      {:ok, obj} =
        create_objective(project, publication, "obj", "Objective", [sub_obj.resource_id])

      {:ok, view, _html} = live(conn, live_view_route(project.slug, %{selected: obj.slug}))

      assert has_element?(view, "##{obj.slug}")
      assert has_element?(view, ".collapse", "#{sub_obj.title}")

      view
      |> element("button[phx-click='display_edit_modal'][phx-value-slug=#{sub_obj.slug}]")
      |> render_click(%{"slug" => sub_obj.slug})

      view
      |> element("form[phx-submit='edit']")
      |> render_submit(%{"revision" => %{"title" => title, "slug" => sub_obj.slug}})

      assert view
             |> element(~s{div[role="alert"].alert-info})
             |> render() =~
               "Objective successfully updated"

      assert 2 ==
               project
               |> ObjectiveEditor.fetch_objective_mappings()
               |> length()

      refute has_element?(view, ".collapse", "#{sub_obj.title}")
      assert has_element?(view, ".collapse", "#{title}")

      wait_for_coverage(view)
    end

    test "remove sub objective with one parent", %{
      conn: conn,
      project: project,
      publication: publication
    } do
      {:ok, sub_obj} = create_objective(project, publication, "sub_obj", "Sub Objective")

      {:ok, obj} =
        create_objective(project, publication, "obj", "Objective", [sub_obj.resource_id])

      {:ok, view, _html} = live(conn, live_view_route(project.slug, %{selected: obj.slug}))

      assert has_element?(view, "##{obj.slug}")
      assert has_element?(view, ".collapse", "#{sub_obj.title}")

      view
      |> element(
        "button[phx-click='display_sub_objective_delete_modal'][phx-value-slug=#{sub_obj.slug}]"
      )
      |> render_click(%{"slug" => sub_obj.slug, "parent_slug" => obj.slug})

      assert has_element?(view, "#delete_sub_objective_modal", "Delete Sub-Objective")
      assert has_element?(view, "#delete_sub_objective_modal", "#{sub_obj.title}")

      view
      |> element("button[phx-click='delete_sub_objective'][phx-value-slug=#{sub_obj.slug}]")
      |> render_click(%{"slug" => sub_obj.slug, "parent_slug" => obj.slug})

      assert has_element?(view, ".collapse .line-through", "#{sub_obj.title}")
      assert has_element?(view, ".collapse .spinner-border")

      wait_until(fn ->
        has_element?(view, ~s{div[role="alert"].alert-info}, "Objective successfully removed")
      end)

      assert 1 ==
               project
               |> ObjectiveEditor.fetch_objective_mappings()
               |> length()

      refute has_element?(view, ".collapse", "#{sub_obj.title}")

      wait_for_coverage(view)
    end

    test "remove sub objective with more than one parent", %{
      conn: conn,
      project: project,
      publication: publication
    } do
      {:ok, sub_obj} = create_objective(project, publication, "sub_obj", "Sub Objective")

      {:ok, obj_a} =
        create_objective(project, publication, "obj_a", "Objective A", [sub_obj.resource_id])

      {:ok, obj_b} =
        create_objective(project, publication, "obj_b", "Objective B", [sub_obj.resource_id])

      {:ok, view, _html} = live(conn, live_view_route(project.slug, %{selected: obj_a.slug}))

      assert has_element?(view, "##{obj_a.slug}")
      assert has_element?(view, "##{obj_b.slug}")
      assert has_element?(view, "##{obj_a.slug} .collapse", "#{sub_obj.title}")

      view
      |> element("button[phx-click='toggle_objective'][phx-value-slug=#{obj_b.slug}]")
      |> render_click(%{"slug" => obj_b.slug})

      assert has_element?(view, "##{obj_b.slug} .collapse", "#{sub_obj.title}")

      view
      |> element(
        "button[phx-click='display_sub_objective_delete_modal'][phx-value-slug=#{sub_obj.slug}][phx-value-parent_slug=#{obj_a.slug}]"
      )
      |> render_click(%{"slug" => sub_obj.slug, "parent_slug" => obj_a.slug})

      assert has_element?(view, "#delete_sub_objective_modal", "Delete Sub-Objective")

      view
      |> element(
        "button[phx-click='delete_sub_objective'][phx-value-slug=#{sub_obj.slug}][phx-value-parent_slug=#{obj_a.slug}]"
      )
      |> render_click(%{"slug" => sub_obj.slug, "parent_slug" => obj_a.slug})

      assert has_element?(view, "##{obj_a.slug} .line-through", "#{sub_obj.title}")
      assert has_element?(view, "##{obj_a.slug} .spinner-border")

      wait_until(fn ->
        has_element?(view, ~s{div[role="alert"].alert-info}, "Objective successfully removed")
      end)

      assert 3 ==
               project
               |> ObjectiveEditor.fetch_objective_mappings()
               |> length()

      refute has_element?(view, "##{obj_a.slug} .collapse", "#{sub_obj.title}")
      assert has_element?(view, "##{obj_b.slug} .collapse", "#{sub_obj.title}")

      wait_for_coverage(view)
    end

    test "renders links to revision history if #show_links is added to the url (being an admin)",
         %{conn: conn, project: project, publication: publication} do
      create_objective(project, publication, "obj_a", "Objective A")

      conn =
        get(conn, "/workspaces/course_author/#{project.slug}/objectives#show_links")
        |> Map.put(
          :request_path,
          "/workspaces/course_author/#{project.slug}/objectives#show_links"
        )

      {:ok, view, _html} = live(conn)

      assert render(view) =~ "View revision history"
    end

    test "does not render links to revision history if #show_links is not added to the url (being an admin)",
         %{conn: conn, project: project, publication: publication} do
      create_objective(project, publication, "obj_a", "Objective A")

      conn = get(conn, "/authoring/project/#{project.slug}/objectives")

      {:ok, view, _html} = live(conn)

      refute render(view) =~ "View revision history"
    end

    test "renders page-first coverage and switches assessment buckets locally", %{
      conn: conn,
      project: project,
      publication: publication
    } do
      {:ok, objective} = create_objective(project, publication, "obj", "Objective")
      {:ok, page} = create_page_with_objective(project, publication, [objective.resource_id])

      {:ok, view, _html} = live(conn, live_view_route(project.slug, %{selected: objective.slug}))
      wait_for_coverage(view)

      assert has_element?(view, "##{objective.slug} .collapse", page.title)
      refute has_element?(view, "##{objective.slug} .collapse", "Attached Content")
      assert has_element?(view, "##{objective.slug} .collapse", "0 Formative")
      assert has_element?(view, "##{objective.slug} .collapse", "0 Summative")

      assert has_element?(
               view,
               "button[phx-click='set_assessment_bucket'][phx-value-bucket=formative]"
             )

      view
      |> element(
        "button[phx-click='set_assessment_bucket'][phx-value-objective_id='#{objective.resource_id}'][phx-value-bucket=summative]"
      )
      |> render_click()

      assert has_element?(view, "##{objective.slug} .collapse", "No pages or activities")

      assert has_element?(
               view,
               "button[phx-click='set_assessment_bucket'][phx-value-bucket=summative]"
             )
    end

    test "links pages and embedded activities to the read-only editor targets", %{
      conn: conn,
      project: project,
      publication: publication
    } do
      {:ok, objective} = create_objective(project, publication, "obj", "Objective")

      {:ok, activity} =
        create_embedded_activity_with_objective(
          project,
          publication,
          objective.resource_id,
          "activity"
        )

      {:ok, page} =
        create_page_with_objective(
          project,
          publication,
          [objective.resource_id],
          "page",
          [activity.resource_id]
        )

      {:ok, view, _html} = live(conn, live_view_route(project.slug, %{selected: objective.slug}))
      wait_for_coverage(view)

      assert has_element?(
               view,
               "a[href='/workspaces/course_author/#{project.slug}/curriculum/#{page.slug}/edit']",
               page.title
             )

      assert has_element?(
               view,
               "a[href='/workspaces/course_author/#{project.slug}/curriculum/#{page.slug}/edit#activity_#{activity.resource_id}']",
               activity.title
             )

      refute has_element?(
               view,
               "a[href='/workspaces/course_author/#{project.slug}/curriculum/#{page.slug}/edit'][phx-click]"
             )

      refute has_element?(
               view,
               "a[href='/workspaces/course_author/#{project.slug}/curriculum/#{page.slug}/edit#activity_#{activity.resource_id}'][phx-click]"
             )
    end

    test "expands child coverage independently with accessible state", %{
      conn: conn,
      project: project,
      publication: publication
    } do
      {:ok, child} = create_objective(project, publication, "child", "Child Objective")

      {:ok, page} =
        create_page_with_objective(project, publication, [child.resource_id], "child-page")

      {:ok, parent} =
        create_objective(project, publication, "parent", "Parent Objective", [child.resource_id])

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      wait_for_coverage(view)

      view
      |> element("button[phx-click='toggle_objective'][phx-value-slug=#{parent.slug}]")
      |> render_click()

      child_toggle = "button[phx-click='toggle_objective'][phx-value-slug=#{child.slug}]"
      assert render(view |> element(child_toggle)) =~ ~s(aria-expanded="false")

      assert render(view |> element(child_toggle)) =~
               ~s(aria-controls="sub-objective-coverage-#{child.resource_id}")

      view |> element(child_toggle) |> render_click()

      assert render(view |> element(child_toggle)) =~ ~s(aria-expanded="true")
      assert has_element?(view, "#sub-objective-coverage-#{child.resource_id}", page.title)
    end

    test "does not render an assessment toggle for objectives without coverage", %{
      conn: conn,
      project: project,
      publication: publication
    } do
      {:ok, objective} = create_objective(project, publication, "empty", "Empty Objective")

      {:ok, view, _html} = live(conn, live_view_route(project.slug))
      wait_for_coverage(view)

      assert has_element?(view, "##{objective.slug}")
      refute has_element?(view, "##{objective.slug} button[phx-click='set_assessment_bucket']")
    end

    test "keeps banked activities out of rendered coverage", %{
      conn: conn,
      project: project,
      publication: publication
    } do
      {:ok, objective} = create_objective(project, publication, "obj", "Objective")

      {:ok, banked_activity} =
        create_embedded_activity_with_objective(
          project,
          publication,
          objective.resource_id,
          "banked-activity",
          :banked
        )

      {:ok, page} =
        create_page_with_objective(
          project,
          publication,
          [objective.resource_id],
          "banked-page",
          [banked_activity.resource_id]
        )

      {:ok, view, _html} = live(conn, live_view_route(project.slug, %{selected: objective.slug}))
      wait_for_coverage(view)

      assert has_element?(view, "##{objective.slug} .collapse", page.title)
      refute has_element?(view, "##{objective.slug}", banked_activity.title)
      refute render(view) =~ "#activity_#{banked_activity.resource_id}"
    end

    test "renders tokenized overflow layout and assessment icons", %{
      conn: conn,
      project: project,
      publication: publication
    } do
      {:ok, objective} = create_objective(project, publication, "obj", "Objective")

      {:ok, formative_activity} =
        create_embedded_activity_with_objective(
          project,
          publication,
          objective.resource_id,
          "formative-activity"
        )

      {:ok, summative_activity} =
        create_embedded_activity_with_objective(
          project,
          publication,
          objective.resource_id,
          "summative-activity"
        )

      {:ok, formative_page} =
        create_page_with_objective(
          project,
          publication,
          [objective.resource_id],
          "formative-page",
          [formative_activity.resource_id]
        )

      {:ok, _summative_page} =
        create_page_with_objective(
          project,
          publication,
          [objective.resource_id],
          "summative-page",
          [summative_activity.resource_id],
          true
        )

      {:ok, view, _html} = live(conn, live_view_route(project.slug, %{selected: objective.slug}))
      wait_for_coverage(view)

      assert render(view) =~ "h-[42px] items-center rounded-md border"
      assert has_element?(view, "svg[role='practice icon']")
      assert has_element?(view, "##{objective.slug} .collapse", formative_page.title)

      view
      |> element(
        "button[phx-click='set_assessment_bucket'][phx-value-objective_id='#{objective.resource_id}'][phx-value-bucket=summative]"
      )
      |> render_click()

      assert has_element?(view, "svg[role='assignments icon']")
    end
  end
end
