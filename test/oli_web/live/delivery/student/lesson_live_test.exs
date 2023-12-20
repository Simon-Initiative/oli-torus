defmodule OliWeb.Delivery.Student.LessonLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory
  import Ecto.Query, warn: false

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Resources.ResourceType

  defp live_view_content_live_route(section_slug) do
    ~p"/sections/#{section_slug}/learn"
  end

  defp live_view_lesson_live_route(section_slug, revision_slug) do
    ~p"/sections/#{section_slug}/lesson/#{revision_slug}"
  end

  defp create_elixir_project(_) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # revisions...
    ## pages...
    page_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 1",
        duration_minutes: 10
      )

    page_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 2",
        duration_minutes: 15
      )

    ## modules...
    module_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_1_revision.resource_id, page_2_revision.resource_id],
        title: "How to use this course",
        poster_image: "module_1_custom_image_url",
        intro_content: %{
          children: [
            %{
              type: "p",
              children: [
                %{
                  text: "Thoughout this unit you will learn how to use this course."
                }
              ]
            }
          ]
        }
      })

    ## units...
    unit_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [module_1_revision.resource_id],
        title: "Introduction",
        poster_image: "some_image_url",
        intro_video: "some_video_url"
      })

    ## root container...
    container_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [
          unit_1_revision.resource_id
        ],
        title: "Root Container"
      })

    all_revisions =
      [
        page_1_revision,
        page_2_revision,
        module_1_revision,
        unit_1_revision,
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
      insert(:publication, %{project: project, root_resource_id: container_revision.resource_id})

    # publish resources
    Enum.each(all_revisions, fn revision ->
      insert(:published_resource, %{
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: author
      })
    end)

    # create section...
    section =
      insert(:section,
        base_project: project,
        title: "The best course ever!",
        start_date: ~U[2023-10-30 20:00:00Z]
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section)

    # schedule start and end date for unit 1 section resource
    Sections.get_section_resource(section.id, unit_1_revision.resource_id)
    |> Sections.update_section_resource(%{
      start_date: ~U[2023-10-31 20:00:00Z],
      end_date: ~U[2023-12-31 20:00:00Z]
    })

    {:ok, _} = Sections.rebuild_full_hierarchy(section)

    %{
      section: section,
      page_1: page_1_revision,
      page_2: page_2_revision,
      module_1: module_1_revision,
      unit_1: unit_1_revision
    }
  end

  describe "user" do
    setup [:create_elixir_project]

    test "can not access page when it is not logged in", %{
      conn: conn,
      section: section,
      page_1: page_1
    } do
      student = insert(:user)

      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:error, {:redirect, %{to: redirect_path}}} =
        live(conn, live_view_lesson_live_route(section.slug, page_1.slug))

      assert redirect_path ==
               "/session/new?request_path=%2Fsections%2F#{section.slug}%2Flesson%2F#{page_1.slug}&section=#{section.slug}"
    end
  end

  describe "student" do
    setup [:user_conn, :create_elixir_project]

    test "can not access when not enrolled to course", %{
      conn: conn,
      section: section,
      page_1: page_1
    } do
      {:error, {:redirect, %{to: redirect_path, flash: _flash_msg}}} =
        live(conn, live_view_lesson_live_route(section.slug, page_1.slug))

      assert redirect_path == "/unauthorized"
    end

    test "can access when enrolled to course", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1,
      page_2: page_2,
      module_1: module_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, live_view_lesson_live_route(section.slug, page_1.slug))

      assert has_element?(view, "span", "The best course ever!")

      assert has_element?(
               view,
               ~s{div[role="prev_page"]},
               module_1.title
             )

      assert has_element?(
               view,
               ~s{div[role="next_page"]},
               page_2.title
             )
    end

    test "can navigate between pages", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1,
      page_2: page_2
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, live_view_lesson_live_route(section.slug, page_1.slug))

      view
      |> element(~s{div[role="next_page"] a})
      |> render_click

      assert_redirected(
        view,
        live_view_lesson_live_route(section.slug, page_2.slug)
      )
    end

    test "back link returns to content page", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, live_view_lesson_live_route(section.slug, page_1.slug))

      view
      |> element(~s{div[role="back_link"] a})
      |> render_click

      assert_redirected(
        view,
        live_view_content_live_route(section.slug)
      )
    end
  end
end
