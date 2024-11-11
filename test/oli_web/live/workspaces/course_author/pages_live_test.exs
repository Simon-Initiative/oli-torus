defmodule OliWeb.Workspaces.CourseAuthor.PagesLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Authoring.Course
  alias Oli.Resources
  alias OliWeb.Workspaces.CourseAuthor.PagesLive

  defp live_view_all_pages_route(project_slug) do
    Routes.live_path(OliWeb.Endpoint, PagesLive, project_slug)
  end

  defp insert_pages(project, publication, count) do
    Enum.map(3..count, fn index ->
      nested_page_resource = insert(:resource)

      nested_page_revision =
        insert(:revision, %{
          objectives: %{"attached" => []},
          scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          children: [],
          content: %{"model" => []},
          deleted: false,
          title: "Nested page #{index}",
          resource: nested_page_resource
        })

      insert(:project_resource, %{project_id: project.id, resource_id: nested_page_resource.id})

      insert(:published_resource, %{
        publication: publication,
        resource: nested_page_resource,
        revision: nested_page_revision
      })
    end)
  end

  defp create_project(_) do
    author = insert(:author)

    project = insert(:project, authors: [author])

    nested_page_revision =
      insert(:revision, %{
        objectives: %{"attached" => []},
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        children: [],
        content: %{"model" => []},
        deleted: false,
        title: "Nested page 1",
        author_id: author.id
      })

    nested_page_revision_2 =
      insert(:revision, %{
        objectives: %{"attached" => []},
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        children: [],
        content: %{"model" => []},
        deleted: false,
        title: "Nested page 2",
        graded: true,
        author_id: author.id
      })

    unit_one_revision =
      insert(:revision, %{
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [nested_page_revision.resource_id, nested_page_revision_2.resource_id],
        content: %{"model" => []},
        deleted: false,
        title: "The first unit",
        slug: "first_unit",
        author_id: author.id
      })

    container_revision =
      insert(:revision, %{
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [unit_one_revision.resource_id],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container",
        author_id: author.id
      })

    all_revisions =
      [
        nested_page_revision,
        nested_page_revision_2,
        unit_one_revision,
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

    %{
      publication: publication,
      project: project,
      unit_one_revision: unit_one_revision,
      nested_page_revision: nested_page_revision,
      nested_page_revision_2: nested_page_revision_2
    }
  end

  defp create_project_without_pages(_conn) do
    project = insert(:project)
    container_resource = insert(:resource)

    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})

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

  describe "user cannot access when is not logged in" do
    test "redirects to overview when accessing the all pages view", %{
      conn: conn
    } do
      project = insert(:project)

      redirect_path =
        "/workspaces/course_author"

      {:error,
       {:redirect,
        %{
          to: ^redirect_path
        }}} =
        live(conn, live_view_all_pages_route(project.slug))
    end
  end

  describe "all pages view" do
    setup [:admin_conn, :create_project]

    test "loads all pages view correctly", %{
      conn: conn,
      project: project,
      nested_page_revision: nested_page_revision
    } do
      {:ok, view, _html} = live(conn, live_view_all_pages_route(project.slug))

      assert view
             |> element("#header_id")
             |> render() =~
               "Browse All Pages"

      assert has_element?(view, "button", "Create")

      assert has_element?(
               view,
               "input[id=\"text-search-input\"]"
             )

      assert has_element?(
               view,
               "select[name=\"graded\"][id=\"select_graded\"]"
             )

      assert has_element?(
               view,
               "select[name=\"type\"][id=\"select_type\"]"
             )

      assert has_element?(
               view,
               "table tbody tr:nth-child(1) td:nth-child(1)",
               nested_page_revision.title
             )

      assert has_element?(view, "#header_paging")
      assert has_element?(view, "#footer_paging")
    end

    test "loads correctly when there are no pages in the project", %{
      conn: conn
    } do
      [project: project] = create_project_without_pages(conn)

      {:ok, view, _html} =
        live(conn, live_view_all_pages_route(project.slug))

      assert has_element?(view, "p", "There are no pages in this project")
    end

    test "applies filtering", %{
      conn: conn,
      project: project,
      nested_page_revision: nested_page_revision,
      nested_page_revision_2: nested_page_revision_2
    } do
      {:ok, view, _html} =
        live(conn, live_view_all_pages_route(project.slug))

      assert has_element?(
               view,
               "table tbody tr:nth-child(1) td:nth-child(1)",
               nested_page_revision.title
             )

      assert has_element?(
               view,
               "table tbody tr:nth-child(2) td:nth-child(1)",
               nested_page_revision_2.title
             )

      view
      |> element("form[phx-change=\"change_graded\"")
      |> render_change(%{"graded" => true})

      assert has_element?(
               view,
               "table tbody tr:nth-child(1) td:nth-child(1)",
               nested_page_revision_2.title
             )

      refute has_element?(
               view,
               nested_page_revision.title
             )
    end

    test "applies searching", %{
      conn: conn,
      project: project,
      nested_page_revision: nested_page_revision,
      nested_page_revision_2: nested_page_revision_2
    } do
      {:ok, view, _html} =
        live(conn, live_view_all_pages_route(project.slug))

      assert has_element?(
               view,
               "table tbody tr:nth-child(1) td:nth-child(1)",
               nested_page_revision.title
             )

      assert has_element?(
               view,
               "table tbody tr:nth-child(2) td:nth-child(1)",
               nested_page_revision_2.title
             )

      view
      |> element("#text-search-input")
      |> render_hook("text_search_change", %{value: nested_page_revision.title})

      assert has_element?(
               view,
               "table tbody tr:nth-child(1) td:nth-child(1)",
               nested_page_revision.title
             )

      refute has_element?(
               view,
               nested_page_revision_2.title
             )
    end

    test "applies sorting", %{
      conn: conn,
      project: project,
      nested_page_revision: nested_page_revision,
      nested_page_revision_2: nested_page_revision_2
    } do
      {:ok, view, _html} =
        live(conn, live_view_all_pages_route(project.slug))

      assert view
             |> element("tr:first-child > td:first-child > div")
             |> render() =~
               nested_page_revision.title

      # Sort by title desc
      view
      |> element("th[phx-click=\"paged_table_sort\"]:first-of-type")
      |> render_click(%{sort_by: "title"})

      assert view
             |> element("tr:first-child > td:first-child > div")
             |> render() =~
               nested_page_revision_2.title
    end

    test "applies paging", %{
      conn: conn,
      project: project,
      publication: publication,
      nested_page_revision: nested_page_revision
    } do
      [_first_page | tail] =
        insert_pages(project, publication, 26) |> Enum.sort_by(& &1.revision.title)

      last_page = List.last(tail)

      {:ok, view, _html} =
        live(conn, live_view_all_pages_route(project.slug))

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               nested_page_revision.title

      refute view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               last_page.revision.title

      view
      |> element("#header_paging button[phx-click=\"paged_table_page_change\"]", "2")
      |> render_click()

      refute view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               nested_page_revision.title

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               last_page.revision.title
    end

    test "can open the options modal for a page", %{
      conn: conn,
      project: project,
      nested_page_revision: nested_page_revision
    } do
      {:ok, view, _html} =
        live(conn, live_view_all_pages_route(project.slug))

      refute view
             |> has_element?(
               ~s{div[id='options_modal-container'] h1[id="options_modal-title"]},
               "Page Options"
             )

      view
      |> element(
        ~s{button[role="show_options_modal"][phx-value-slug="#{nested_page_revision.slug}"]},
        "Options"
      )
      |> render_click()

      assert view
             |> has_element?(
               ~s{div[id='options_modal-container'] h1[id="options_modal-title"]},
               "Page Options"
             )
    end

    test "updates the page revision data when a `save-options` event is handled after submitting the options modal",
         %{
           conn: conn,
           project: project,
           nested_page_revision: nested_page_revision
         } do
      {:ok, view, _html} =
        live(conn, live_view_all_pages_route(project.slug))

      assert has_element?(view, "a", "Nested page 1")

      assert %Oli.Resources.Revision{
               retake_mode: :normal,
               assessment_mode: :traditional,
               duration_minutes: nil,
               graded: false,
               max_attempts: 0,
               purpose: :foundation,
               scoring_strategy_id: 1,
               explanation_strategy: nil
             } =
               _initial_revision =
               Oli.Publishing.AuthoringResolver.from_revision_slug(
                 project.slug,
                 nested_page_revision.slug
               )

      view
      |> element(
        ~s{button[role="show_options_modal"][phx-value-slug="#{nested_page_revision.slug}"]},
        "Options"
      )
      |> render_click()

      view
      |> render_hook("save-options", %{
        "revision" => %{
          "duration_minutes" => "5",
          "explanation_strategy" => %{"type" => "after_max_resource_attempts_exhausted"},
          "graded" => "true",
          "max_attempts" => "10",
          "poster_image" => "some_poster_image_url",
          "purpose" => "application",
          "retake_mode" => "targeted",
          "assessment_mode" => "one_at_a_time",
          "scoring_strategy_id" => "2",
          "title" => "New Title!!"
        }
      })

      {path, flash} = assert_redirect(view)

      assert path =~ "/workspaces/course_author/#{project.slug}/pages"
      assert flash == %{"info" => "Page options saved"}

      {:ok, view, _html} =
        live(conn, live_view_all_pages_route(project.slug))

      assert has_element?(view, "a", "New Title!!")

      assert %Oli.Resources.Revision{
               retake_mode: :targeted,
               assessment_mode: :one_at_a_time,
               duration_minutes: 5,
               graded: true,
               max_attempts: 10,
               purpose: :application,
               scoring_strategy_id: 2,
               explanation_strategy: %Oli.Resources.ExplanationStrategy{
                 type: :after_max_resource_attempts_exhausted,
                 set_num_attempts: nil
               },
               poster_image: "some_poster_image_url"
             } =
               _updated_revision =
               Oli.Publishing.AuthoringResolver.from_revision_slug(
                 project.slug,
                 nested_page_revision.slug
               )
    end

    test "create a page and back to the all pages view works correctly", %{
      conn: conn,
      project: project,
      admin: admin
    } do
      {:ok, view, _html} =
        live(conn, live_view_all_pages_route(project.slug))

      ## Create a new page
      view
      |> element(
        "button[phx-click=\"create_page\"][phx-value-type=\"Unscored\"]",
        "Practice Page"
      )
      |> render_click()

      ## Get created page
      new_page =
        project.id
        |> Course.list_project_resources()
        |> Enum.max_by(& &1.resource_id)
        |> Map.get(:resource_id)
        |> then(&Resources.get_revisions_by_resource_id([&1]))
        |> List.first()

      conn = recycle_author_session(conn, admin)

      ## Go to the new page edit view
      {:ok, view, _html} =
        live(conn, "/workspaces/course_author/#{project.slug}/curriculum/#{new_page.slug}/edit")

      assert view
             |> element("li[aria-current=\"page\"]")
             |> render() =~ new_page.title

      ## Go back to the all pages
      view
      |> element("a[href=\"/workspaces/course_author/#{project.slug}/pages\"]", "All Pages")
      |> render_click()

      conn = recycle_author_session(conn, admin)

      {:ok, view, _html} =
        live(conn, live_view_all_pages_route(project.slug))

      ## Check the new page is in the list
      assert view
             |> element(
               "a[href=\"/workspaces/course_author/#{project.slug}/curriculum/#{new_page.slug}/edit\"]"
             )
             |> render() =~
               new_page.title
    end
  end
end
