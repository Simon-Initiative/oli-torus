defmodule OliWeb.ObjectivesLiveTest do
  # TODO: FIX This module generates the following errors in the test logs:
  # 1) 15:39:55.788 [error] Postgrex.Protocol (#PID<0.494.0>) disconnected: **
  #    (DBConnection.ConnectionError) owner #PID<0.643.0> exited
  # 2) Client #PID<0.762.0> is still using a connection from owner at location ...
  #
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Oli.Authoring.Editing.ObjectiveEditor
  alias Oli.Resources.ResourceType

  defp live_view_route(project_slug, params \\ %{}),
    do: Routes.live_path(OliWeb.Endpoint, OliWeb.ObjectivesLive.Objectives, project_slug, params)

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

  defp create_page_with_objective(project, publication, objectives, slug \\ "slug") do
    # Create page
    page_resource = insert(:resource)

    page_revision =
      insert(:revision, %{
        objectives: %{"attached" => objectives},
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
        resource_type_id: ResourceType.id_for_page(),
        children: [],
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
      assert has_element?(view, "p", "None exist")

      assert_receive {:finish_attachments, {_attachments, _flash_fn}}
      assert_receive {:DOWN, _ref, :process, _pid, :normal}
    end

    @tag :skip
    test "applies searching", %{conn: conn, project: project, publication: publication} do
      {:ok, first_obj} = create_objective(project, publication, "first_obj", "First Objective")
      {:ok, second_obj} = create_objective(project, publication, "second_obj", "Second Objective")

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      assert has_element?(view, "#objectives-table")
      assert has_element?(view, "##{first_obj.slug}")
      assert has_element?(view, "##{second_obj.slug}")

      view
      |> element("input[phx-blur=\"change_search\"]")
      |> render_blur(%{value: "first"})

      view
      |> element("button[phx-click=\"apply_search\"]")
      |> render_click()

      assert has_element?(view, "##{first_obj.slug}")
      refute has_element?(view, "##{second_obj.slug}")

      view
      |> element("button[phx-click=\"reset_search\"]")
      |> render_click()

      assert has_element?(view, "##{first_obj.slug}")
      assert has_element?(view, "##{second_obj.slug}")

      assert_receive {:finish_attachments, {_attachments, _flash_fn}}
      assert_receive {:DOWN, _ref, :process, _pid, :normal}
    end

    test "applies sorting", %{conn: conn, project: project, publication: publication} do
      {:ok, _first_obj} = create_objective(project, publication, "first_obj", "First Objective")

      {:ok, _second_obj} =
        create_objective(project, publication, "second_obj", "Second Objective")

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      assert view
             |> element(".card:first-child")
             |> render() =~
               "First Objective"

      view
      |> element("form[phx-change=\"sort\"")
      |> render_change(%{sort_by: "title"})

      assert view
             |> element(".card:first-child")
             |> render() =~
               "Second Objective"

      assert_receive {:finish_attachments, {_attachments, _flash_fn}}
      assert_receive {:DOWN, _ref, :process, _pid, :normal}
    end

    test "applies paging", %{conn: conn, project: project, publication: publication} do
      [first_obj | tail] =
        1..21
        |> Enum.to_list()
        |> Enum.map(fn i ->
          create_objective(project, publication, "#{i}_obj", "#{i} Objective") |> elem(1)
        end)
        |> Enum.sort_by(& &1.title)

      last_obj = List.last(tail)

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      assert has_element?(view, "##{first_obj.slug}")
      refute has_element?(view, "##{last_obj.slug}")

      view
      |> element(
        "#header_paging > nav > ul > li:nth-child(4) > button",
        "2"
      )
      |> render_click()

      refute has_element?(view, "##{first_obj.slug}")
      assert has_element?(view, "##{last_obj.slug}")

      assert_receive {:finish_attachments, {_attachments, _flash_fn}}
      assert_receive {:DOWN, _ref, :process, _pid, :normal}
    end

    @tag :skip
    test "show objective", %{conn: conn, project: project, publication: publication} do
      {:ok, sub_obj} = create_objective(project, publication, "sub_obj", "Sub Objective")
      {:ok, sub_obj_2} = create_objective(project, publication, "sub_obj_2", "Sub Objective 2")

      {:ok, obj} =
        create_objective(project, publication, "obj", "Objective", [
          sub_obj.resource_id,
          sub_obj_2.resource_id
        ])

      {:ok, page_1} =
        create_page_with_objective(project, publication, [obj.resource_id], "other_slug")

      {:ok, page_2} =
        create_page_with_objective(project, publication, [
          sub_obj.resource_id,
          sub_obj_2.resource_id
        ])

      {:ok, view, _html} = live(conn, live_view_route(project.slug, %{selected: obj.slug}))

      assert has_element?(view, "##{obj.slug}")
      assert has_element?(view, "##{obj.slug}", "Sub-Objectives 2")
      assert has_element?(view, "##{obj.slug}", "Pages 2")
      assert has_element?(view, "##{obj.slug}", "Activities 0")
      assert has_element?(view, ".collapse", "Sub-Objectives")
      assert has_element?(view, ".collapse", "#{sub_obj.title}")
      assert has_element?(view, ".collapse", "Pages")

      assert has_element?(
               view,
               ".collapse a[href=\"#{Routes.resource_path(OliWeb.Endpoint, :edit, project.slug, page_1.slug)}\"]",
               "#{page_1.title}"
             )

      assert has_element?(
               view,
               ".collapse a[href=\"#{Routes.resource_path(OliWeb.Endpoint, :edit, project.slug, page_2.slug)}\"]",
               "#{page_2.title}"
             )

      assert_receive {:finish_attachments, {_attachments, _flash_fn}}
      assert_receive {:DOWN, _ref, :process, _pid, :normal}
    end

    @tag :flaky
    test "new objective", %{conn: conn, project: project} do
      title = "New Objective"

      {:ok, view, _html} = live(conn, live_view_route(project.slug))

      refute has_element?(view, "#{title}")

      view
      |> element("button[phx-click=\"display_new_modal\"]")
      |> render_click(%{})

      view
      |> element("form[phx-submit=\"new\"")
      |> render_submit(%{"revision" => %{"title" => title, "parent_slug" => ""}})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Objective successfully created"

      [%{revision: revision} | _tail] = ObjectiveEditor.fetch_objective_mappings(project)

      assert has_element?(view, "##{revision.slug}")
      assert has_element?(view, "button[phx-value-slug=#{revision.slug}]", "#{revision.title}")

      assert_receive {:finish_attachments, {_attachments, _flash_fn}}
      assert_receive {:DOWN, _ref, :process, _pid, :normal}
    end

    test "edit objective", %{conn: conn, project: project, publication: publication} do
      title = "New title"
      {:ok, obj} = create_objective(project, publication, "obj", "Objective")

      {:ok, view, _html} = live(conn, live_view_route(project.slug, %{selected: obj.slug}))

      assert has_element?(view, "##{obj.slug}")
      assert has_element?(view, "button[phx-value-slug=#{obj.slug}]", "#{obj.title}")

      view
      |> element("button[phx-click=\"display_edit_modal\"]")
      |> render_click(%{"slug" => obj.slug})

      view
      |> element("form[phx-submit=\"edit\"")
      |> render_submit(%{"revision" => %{"title" => title, "slug" => obj.slug}})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Objective successfully updated"

      [%{revision: new_obj} | _tail] = ObjectiveEditor.fetch_objective_mappings(project)

      refute has_element?(view, "button[phx-value-slug=#{obj.slug}]", "#{obj.title}")
      assert has_element?(view, "button[phx-value-slug=#{new_obj.slug}]", "#{title}")

      assert_receive {:finish_attachments, {_attachments, _flash_fn}}
      assert_receive {:DOWN, _ref, :process, _pid, :normal}
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
      |> element("button[phx-click=\"set_selected\"][phx-value-slug=#{obj_a.slug}]")
      |> render_click(%{"slug" => obj_a.slug})

      view
      |> element("button[phx-click=\"display_delete_modal\"][phx-value-slug=#{obj_a.slug}]")
      |> render_click(%{"slug" => obj_a.slug})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Could not remove objective if it has sub-objectives associated"

      view
      |> element("button[phx-click=\"set_selected\"][phx-value-slug=#{obj_b.slug}]")
      |> render_click(%{"slug" => obj_b.slug})

      view
      |> element("button[phx-click=\"display_delete_modal\"][phx-value-slug=#{obj_b.slug}]")
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
      |> element("button[phx-click=\"set_selected\"][phx-value-slug=#{obj_c.slug}]")
      |> render_click(%{"slug" => obj_c.slug})

      view
      |> element("button[phx-click=\"display_delete_modal\"][phx-value-slug=#{obj_c.slug}]")
      |> render_click(%{"slug" => obj_c.slug})

      view
      |> element("button[phx-click=\"delete\"][phx-value-slug=#{obj_c.slug}]")
      |> render_click(%{"slug" => obj_c.slug, "parent_slug" => ""})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Objective successfully removed"

      assert 3 ==
               project
               |> ObjectiveEditor.fetch_objective_mappings()
               |> length()

      refute has_element?(view, ".collapse", "#{removal_title}")

      assert_receive {:finish_attachments, {_attachments, _flash_fn}}
      assert_receive {:DOWN, _ref, :process, _pid, :normal}
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

      refute has_element?(view, "#collapse0", "#{sub_obj_b.title}")

      view
      |> element(
        "button[phx-click=\"display_add_existing_sub_modal\"][phx-value-slug=#{first_obj.slug}]"
      )
      |> render_click(%{slug: first_obj.slug})

      refute has_element?(
               view,
               "button[phx-click=\"add_existing_sub\"][phx-value-slug=#{sub_obj_a.slug}]",
               "Add"
             )

      assert has_element?(
               view,
               "button[phx-click=\"add_existing_sub\"][phx-value-slug=#{sub_obj_b.slug}]",
               "Add"
             )

      assert has_element?(
               view,
               "button[phx-click=\"add_existing_sub\"][phx-value-slug=#{sub_obj_c.slug}]",
               "Add"
             )

      view
      |> element("#select_existing_sub_modal #text-search-input")
      |> render_hook("text_search_change", %{value: "testing"})

      assert has_element?(
               view,
               "button[phx-click=\"add_existing_sub\"][phx-value-slug=#{sub_obj_b.slug}]",
               "Add"
             )

      refute has_element?(
               view,
               "button[phx-click=\"add_existing_sub\"][phx-value-slug=#{sub_obj_c.slug}]",
               "Add"
             )

      view
      |> element(
        "button[phx-click=\"add_existing_sub\"][phx-value-slug=#{sub_obj_b.slug}]",
        "Add"
      )
      |> render_click(%{"slug" => sub_obj_b.slug, "parent_slug" => first_obj.slug})

      assert has_element?(view, ".collapse", "#{sub_obj_b.title}")
      assert has_element?(view, ".collapse", "#{sub_obj_b.title}")

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Sub-objective successfully added"

      assert 5 ==
               project
               |> ObjectiveEditor.fetch_objective_mappings()
               |> length()

      assert_receive {:finish_attachments, {_attachments, _flash_fn}}
      assert_receive {:DOWN, _ref, :process, _pid, :normal}
    end

    test "new sub objective", %{conn: conn, project: project, publication: publication} do
      title = "Sub Objective"
      {:ok, obj} = create_objective(project, publication, "obj", "Objective")

      {:ok, view, _html} = live(conn, live_view_route(project.slug, %{selected: obj.slug}))

      view
      |> element("button[phx-click=\"display_new_sub_modal\"][phx-value-slug=#{obj.slug}]")
      |> render_click(%{slug: obj.slug})

      view
      |> element("form[phx-submit=\"new\"")
      |> render_submit(%{"revision" => %{"title" => title, "parent_slug" => obj.slug}})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Objective successfully created"

      assert 2 ==
               project
               |> ObjectiveEditor.fetch_objective_mappings()
               |> length()

      assert has_element?(view, ".collapse", "#{title}")

      assert_receive {:finish_attachments, {_attachments, _flash_fn}}
      assert_receive {:DOWN, _ref, :process, _pid, :normal}
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
      |> element("button[phx-click=\"display_edit_modal\"][phx-value-slug=#{sub_obj.slug}]")
      |> render_click(%{"slug" => sub_obj.slug})

      view
      |> element("form[phx-submit=\"edit\"")
      |> render_submit(%{"revision" => %{"title" => title, "slug" => sub_obj.slug}})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Objective successfully updated"

      assert 2 ==
               project
               |> ObjectiveEditor.fetch_objective_mappings()
               |> length()

      refute has_element?(view, ".collapse", "#{sub_obj.title}")
      assert has_element?(view, ".collapse", "#{title}")

      assert_receive {:finish_attachments, {_attachments, _flash_fn}}
      assert_receive {:DOWN, _ref, :process, _pid, :normal}
    end

    @tag :skip
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
      |> element("button[phx-click=\"delete\"][phx-value-slug=#{sub_obj.slug}]")
      |> render_click(%{"slug" => sub_obj.slug, "parent_slug" => obj.slug})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Objective successfully removed"

      assert 1 ==
               project
               |> ObjectiveEditor.fetch_objective_mappings()
               |> length()

      refute has_element?(view, ".collapse", "#{sub_obj.title}")

      assert_receive {:finish_attachments, {_attachments, _flash_fn}}
      assert_receive {:DOWN, _ref, :process, _pid, :normal}
    end

    @tag :flaky
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
      assert has_element?(view, "##{obj_b.slug} .collapse", "#{sub_obj.title}")

      view
      |> element(
        "button[phx-click=\"delete\"][phx-value-slug=#{sub_obj.slug}][phx-value-parent_slug=#{obj_a.slug}]"
      )
      |> render_click(%{"slug" => sub_obj.slug, "parent_slug" => obj_a.slug})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Objective successfully removed"

      assert 3 ==
               project
               |> ObjectiveEditor.fetch_objective_mappings()
               |> length()

      refute has_element?(view, "##{obj_a.slug} .collapse", "#{sub_obj.title}")
      assert has_element?(view, "##{obj_b.slug} .collapse", "#{sub_obj.title}")

      assert_receive {:finish_attachments, {_attachments, _flash_fn}}
      assert_receive {:DOWN, _ref, :process, _pid, :normal}
    end

    test "renders links to revision history if #show_links is added to the url (being an admin)",
         %{conn: conn, project: project, publication: publication} do
      create_objective(project, publication, "obj_a", "Objective A")

      conn =
        get(conn, "/authoring/project/#{project.slug}/objectives#show_links")
        |> Map.put(
          :request_path,
          "/authoring/project/#{project.slug}/curriculum#show_links"
        )

      {:ok, view, _html} = live(conn)

      assert render(view) =~ "View revision history"
    end

    test "does not render links to revision history if #show_links is not added to the url (being an admin)",
         %{conn: conn, project: project, publication: publication} do
      create_objective(project, publication, "obj_a", "Objective A")

      conn = get(conn, "/workspaces/course_author/#{project.slug}/objectives")

      {:ok, view, _html} = live(conn)

      refute render(view) =~ "View revision history"
    end
  end
end
