defmodule OliWeb.History.RevisionHistoryTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Resources.ResourceType

  defp revision_history_route(project_slug, revision_slug) do
    ~p[/project/#{project_slug}/history/slug/#{revision_slug}]
  end

  defp create_project(_conn) do
    author = author_fixture()
    project = insert(:project, %{authors: [author]})

    # revisions...
    objective_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_objective(),
        title: "Objective 1"
      )

    objective_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_objective(),
        title: "Objective 2"
      )

    page_1_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.id_for_page(),
        author_id: author.id
      })

    page_2_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.id_for_page(),
        author_id: author.id
      })

    unit_1_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.id_for_container(),
        children: [page_1_revision.resource_id],
        objectives: %{
          attached: [objective_1_revision.resource_id, objective_2_revision.resource_id]
        },
        title: "Unit 1",
        author_id: author.id
      })

    unit_2_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.id_for_container(),
        children: [page_2_revision.resource_id],
        title: "Unit 2",
        author_id: author.id
      })

    container_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.id_for_container(),
        children: [unit_1_revision.resource_id, unit_2_revision.resource_id],
        slug: "root_container",
        title: "Root Container",
        author_id: author.id
      })

    # asociate resources to project

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: objective_1_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: objective_2_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: page_1_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: page_2_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: unit_1_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: unit_2_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: container_revision.resource.id
    })

    # publish project and resources
    publication =
      insert(:publication, %{
        project: project,
        published: nil,
        root_resource_id: container_revision.resource.id
      })

    insert(:published_resource, %{
      publication: publication,
      resource: objective_1_revision.resource,
      revision: objective_1_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: objective_2_revision.resource,
      revision: objective_2_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_1_revision.resource,
      revision: page_1_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_2_revision.resource,
      revision: page_2_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: unit_1_revision.resource,
      revision: unit_1_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: unit_2_revision.resource,
      revision: unit_2_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: container_revision.resource,
      revision: container_revision,
      author: author
    })

    %{
      project: project,
      page_1_revision: page_1_revision,
      page_2_revision: page_2_revision,
      unit_1_revision: unit_1_revision,
      unit_2_revision: unit_2_revision,
      container_revision: container_revision,
      author: author,
      objective_1_revision: objective_1_revision,
      objective_2_revision: objective_2_revision
    }
  end

  describe "user cannot access when is not logged in" do
    setup [:create_project]

    test "redirects to new session when accessing the revision history view", %{
      conn: conn,
      project: project,
      container_revision: container_revision
    } do
      {:error, {:redirect, %{to: redirect_path}}} =
        live(conn, revision_history_route(project.slug, container_revision.slug))

      assert redirect_path == "/authors/log_in"
    end
  end

  describe "user cannot access when logged in" do
    setup [:create_project]

    test "as an author that is not a content admin", %{
      conn: conn,
      project: project,
      container_revision: container_revision
    } do
      %{conn: conn} = register_and_log_in_author(%{conn: conn})

      {:error, {:redirect, %{flash: %{"error" => flash_message}, to: redirect_path}}} =
        live(conn, revision_history_route(project.slug, container_revision.slug))

      assert redirect_path == "/workspaces/course_author"
      assert flash_message == "You must be a content admin to access this page."
    end

    test "as an author that is a collaborator of that project", %{
      conn: conn,
      project: project,
      container_revision: container_revision,
      author: author_project_creator
    } do
      conn = log_in_author(conn, author_project_creator)

      {:error, {:redirect, %{flash: %{"error" => flash_message}, to: redirect_path}}} =
        live(conn, revision_history_route(project.slug, container_revision.slug))

      assert redirect_path == "/workspaces/course_author"
      assert flash_message == "You must be a content admin to access this page."
    end

    test "as an user", %{
      conn: conn,
      project: project,
      container_revision: container_revision
    } do
      user = insert(:user)

      conn =
        conn
        |> log_in_user(user)
        |> get(revision_history_route(project.slug, container_revision.slug))

      assert response(conn, 302)
    end
  end

  describe "revision history (as an admin)" do
    setup [:create_project, :admin_conn]

    test "redirects to /not_found when revision does not exist", %{
      conn: conn,
      project: project
    } do
      {:error, {:redirect, %{flash: %{}, to: redirect_path}}} =
        live(conn, revision_history_route(project.slug, "a_not_existing_revision_slug"))

      assert redirect_path == "/not_found"
    end

    test "can be acceded when revision exists", %{
      conn: conn,
      project: project,
      container_revision: container_revision
    } do
      {:ok, view, _html} =
        live(conn, revision_history_route(project.slug, container_revision.slug))

      assert has_element?(view, "h2", "Revision History")
      assert has_element?(view, "h4", "Resource ID: #{container_revision.resource.id}")
    end

    test "graph is renered with the corresponding revision id", %{
      conn: conn,
      project: project,
      page_1_revision: page_1_revision
    } do
      {:ok, view, _html} = live(conn, revision_history_route(project.slug, page_1_revision.slug))

      assert element(view, "#graph text")
             |> render() =~ "#{page_1_revision.id}"
    end

    test "root revision link does not get rendered if selected revision is the root one", %{
      conn: conn,
      project: project,
      container_revision: container_revision
    } do
      {:ok, view, _html} =
        live(conn, revision_history_route(project.slug, container_revision.slug))

      refute has_element?(view, "#root_hierarchy_link", "Hierarchy")
    end

    test "root revision link gets rendered if selected revision is not the root one", %{
      conn: conn,
      project: project,
      page_1_revision: page_1_revision,
      container_revision: container_revision
    } do
      {:ok, view, _html} = live(conn, revision_history_route(project.slug, page_1_revision.slug))

      assert has_element?(view, "#root_hierarchy_link", "Hierarchy")

      assert element(view, "#root_hierarchy_link")
             |> render() =~
               ~s[href="/project/#{project.slug}/history/slug/#{container_revision.slug}"]
    end

    test "revision details table: can edit 'children' attr", %{
      conn: conn,
      project: project,
      unit_1_revision: unit_1_revision,
      page_1_revision: page_1_revision
    } do
      {:ok, view, _html} = live(conn, revision_history_route(project.slug, unit_1_revision.slug))

      refute has_element?(view, "#edit_attribute_modal")

      # we check that the original value for the 'children' attribute
      # is a list with links to the resource ids
      assert element(view, "#revision-table-children-attr td:nth-of-type(2)")
             |> render() =~
               ~s"[<a href=\"/project/#{project.slug}/history/slug/#{page_1_revision.slug}\" data-phx-link=\"redirect\" data-phx-link-state=\"push\">#{page_1_revision.resource_id}</a>]"

      # click the edit button
      view
      |> element("#revision-table-children-attr td:nth-of-type(2) button")
      |> render_click()

      # LiveViewTest doesn't support testing two or more JS.push chained so we need to trigger two events separatedly
      view
      |> with_target("#attributes_table")
      |> render_click("edit_attribute", %{"attr-key" => "children"})

      # the modal is shown
      assert has_element?(view, "#edit_attribute_modal")
      # with the title of the attribute being edited
      assert has_element?(view, "#edit_attribute_modal-title i", "Children")

      # LiveViewTest doesn't support testing two or more JS.push chained so we need to trigger two events separatedly
      view
      |> with_target("#edit_attribute_modal")
      |> render_click("save_edit_attribute", %{})

      view
      |> with_target("#edit_attribute_modal")
      |> render_click(
        "monaco_editor_get_attribute_value",
        %{
          "meta" => %{"action" => "save"},
          "value" => "[]"
        }
      )

      # a flash message confirms the edit
      assert has_element?(view, "#live_flash_container", "Revision 'children' updated")

      # and we see the value updated in the table
      assert element(view, "#revision-table-children-attr td:nth-of-type(2)")
             |> render() =~ "[]"
    end

    test "revision details table: can edit 'objectives' attr", %{
      conn: conn,
      project: project,
      unit_1_revision: unit_1_revision,
      objective_1_revision: objective_1_revision,
      objective_2_revision: objective_2_revision
    } do
      {:ok, view, _html} = live(conn, revision_history_route(project.slug, unit_1_revision.slug))

      refute has_element?(view, "#edit_attribute_modal")

      # we check that the original value for the 'objectives' attribute
      # is a list with links to the resource ids
      assert element(view, "#revision-table-objectives-attr td:nth-of-type(2)")
             |> render() =~
               ~s"[<a href=\"/project/#{project.slug}/history/slug/#{objective_1_revision.slug}\" data-phx-link=\"redirect\" data-phx-link-state=\"push\">#{objective_1_revision.resource_id}</a>, <a href=\"/project/#{project.slug}/history/slug/#{objective_2_revision.slug}\" data-phx-link=\"redirect\" data-phx-link-state=\"push\">#{objective_2_revision.resource_id}</a>]"

      # click the edit button
      view
      |> element("#revision-table-objectives-attr td:nth-of-type(2) button")
      |> render_click()

      # LiveViewTest doesn't support testing two or more JS.push chained so we need to trigger two events separatedly
      view
      |> with_target("#attributes_table")
      |> render_click("edit_attribute", %{"attr-key" => "objectives"})

      # the modal is shown
      assert has_element?(view, "#edit_attribute_modal")
      # with the title of the attribute being edited
      assert has_element?(view, "#edit_attribute_modal-title i", "Objectives")

      # LiveViewTest doesn't support testing two or more JS.push chained so we need to trigger two events separatedly
      view
      |> with_target("#edit_attribute_modal")
      |> render_click("save_edit_attribute", %{})

      view
      |> with_target("#edit_attribute_modal")
      |> render_click(
        "monaco_editor_get_attribute_value",
        %{
          "meta" => %{"action" => "save"},
          "value" => "{\n  \"attached\": []\n}"
        }
      )

      # a flash message confirms the edit
      assert has_element?(view, "#live_flash_container", "Revision 'objectives' updated")

      # and we see the value updated in the table
      assert element(view, "#revision-table-objectives-attr td:nth-of-type(2)")
             |> render() =~ "[]"
    end

    test "revision details table: an error message is shown when edit fails", %{
      conn: conn,
      project: project,
      unit_1_revision: unit_1_revision
    } do
      {:ok, view, _html} = live(conn, revision_history_route(project.slug, unit_1_revision.slug))

      # click the edit button
      view
      |> element("#revision-table-children-attr td:nth-of-type(2) button")
      |> render_click()

      # LiveViewTest doesn't support testing two or more JS.push chained so we need to trigger two events separatedly
      view
      |> with_target("#attributes_table")
      |> render_click("edit_attribute", %{"attr-key" => "children"})

      view
      |> with_target("#edit_attribute_modal")
      |> render_click("save_edit_attribute", %{})

      view
      |> with_target("#edit_attribute_modal")
      |> render_click(
        "monaco_editor_get_attribute_value",
        %{
          "meta" => %{"action" => "save"},
          "value" => "[an in va lid va lue]"
        }
      )

      # a flash message confirms the edit
      assert has_element?(
               view,
               "#live_flash_container",
               "Could not update revision: Invalid JSON format"
             )
    end
  end
end
