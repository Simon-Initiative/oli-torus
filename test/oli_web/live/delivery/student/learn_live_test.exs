defmodule OliWeb.Delivery.Student.ContentLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory
  import Ecto.Query, warn: false

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Resources.ResourceType
  alias Oli.Delivery.Attempts.Core

  defp live_view_learn_live_route(section_slug) do
    ~p"/sections/#{section_slug}/learn"
  end

  defp set_progress(section_id, resource_id, user_id, progress, revision) do
    {:ok, resource_access} =
      Core.track_access(resource_id, section_id, user_id)
      |> Core.update_resource_access(%{progress: progress})

    insert(:resource_attempt, %{
      resource_access: resource_access,
      revision: revision,
      lifecycle_state: :evaluated
    })
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

    page_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 3"
      )

    page_4_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 4"
      )

    page_5_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 5"
      )

    page_6_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 6"
      )

    page_7_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 7"
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

    module_2_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_3_revision.resource_id, page_4_revision.resource_id],
        title: "Configure your setup"
      })

    module_3_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_5_revision.resource_id, page_6_revision.resource_id],
        title: "Installing Elixir, OTP and Phoenix"
      })

    ## units...
    unit_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [module_1_revision.resource_id, module_2_revision.resource_id],
        title: "Introduction",
        poster_image: "some_image_url",
        intro_video: "some_video_url"
      })

    unit_2_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [module_3_revision.resource_id],
        title: "Building a Phoenix app",
        poster_image: "some_other_image_url"
      })

    unit_3_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_7_revision.resource_id],
        title: "Implementing LiveView"
      })

    ## root container...
    container_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [
          unit_1_revision.resource_id,
          unit_2_revision.resource_id,
          unit_3_revision.resource_id
        ],
        title: "Root Container"
      })

    all_revisions =
      [
        page_1_revision,
        page_2_revision,
        page_3_revision,
        page_4_revision,
        page_5_revision,
        page_6_revision,
        page_7_revision,
        module_1_revision,
        module_2_revision,
        module_3_revision,
        unit_1_revision,
        unit_2_revision,
        unit_3_revision,
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
      page_3: page_3_revision,
      page_4: page_4_revision,
      page_5: page_5_revision,
      page_6: page_6_revision,
      page_7: page_7_revision,
      module_1: module_1_revision,
      module_2: module_2_revision,
      module_3: module_3_revision,
      unit_1: unit_1_revision,
      unit_2: unit_2_revision,
      unit_3: unit_3_revision
    }
  end

  describe "user" do
    test "can not access page when it is not logged in", %{conn: conn} do
      section = insert(:section)
      student = insert(:user)

      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:error, {:redirect, %{to: redirect_path}}} =
        live(conn, live_view_learn_live_route(section.slug))

      assert redirect_path ==
               "/session/new?request_path=%2Fsections%2F#{section.slug}%2Flearn&section=#{section.slug}"
    end
  end

  describe "student" do
    setup [:user_conn, :create_elixir_project]

    test "can not access when not enrolled to course", %{conn: conn, section: section} do
      {:error, {:redirect, %{to: redirect_path, flash: _flash_msg}}} =
        live(conn, live_view_learn_live_route(section.slug))

      assert redirect_path == "/unauthorized"
    end

    test "can access when enrolled to course", %{conn: conn, user: user, section: section} do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      assert has_element?(view, "span", "The best course ever!")
      assert has_element?(view, "h3", "Introduction")
      assert has_element?(view, "h3", "Building a Phoenix app")
      assert has_element?(view, "h3", "Implementing LiveView")
    end

    test "can see unit intro as first slider card and play the video (if provided)", %{
      conn: conn,
      user: user,
      section: section
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      # unit 1 has an intro card with a video url provided, so there must be a play button
      assert has_element?(
               view,
               ~s{div[role="unit_1"] div[role="slider"] div[role="intro_card"] button[role="play_unit_intro_video"]}
             )

      # unit 2 has an intro card without video url (only poster_image was provided)
      assert has_element?(
               view,
               ~s{div[role="unit_2"] div[role="slider"] div[role="intro_card"]}
             )

      refute has_element?(
               view,
               ~s{div[role="unit_2"] div[role="slider"] div[role="intro_card"] button[role="play_unit_intro_video"]}
             )

      # unit 3 has no intro card at all
      refute has_element?(
               view,
               ~s{div[role="unit_3"] div[role="slider"] div[role="intro_card"]}
             )
    end

    test "can expand a module card to view its details (intro content and page details)", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1,
      page_2: page_2
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      refute has_element?(
               view,
               ~s{div[phx-click="navigate_to_resource"][phx-value-slug="#{page_1.slug}"]}
             )

      view
      |> element(~s{div[role="unit_1"] div[role="card_1"]})
      |> render_click()

      # page 1 and page 2 are shown with their estimated read time
      page_1_element =
        element(
          view,
          ~s{div[phx-click="navigate_to_resource"][phx-value-slug="#{page_1.slug}"]}
        )

      assert render(page_1_element) =~ "Page 1"
      assert render(page_1_element) =~ "10"
      assert render(page_1_element) =~ "min"

      page_2_element =
        element(
          view,
          ~s{div[phx-click="navigate_to_resource"][phx-value-slug="#{page_2.slug}"]}
        )

      assert render(page_2_element) =~ "Page 2"
      assert render(page_2_element) =~ "15"
      assert render(page_2_element) =~ "min"

      # intro content is shown
      assert has_element?(view, "p", "Thoughout this unit you will learn how to use this course.")
    end

    test "can expand more than one module card", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1,
      page_5: page_5
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      # page 1 belongs to module 1 (of unit 1) and page 5 belongs to module 3 (of unit 2)
      # Both should not be visible since they are not expanded yet
      refute has_element?(
               view,
               ~s{div[phx-click="navigate_to_resource"][phx-value-slug="#{page_1.slug}"]}
             )

      refute has_element?(
               view,
               ~s{div[phx-click="navigate_to_resource"][phx-value-slug="#{page_5.slug}"]}
             )

      # expand unit 1/module 1 details
      view
      |> element(~s{div[role="unit_1"] div[role="card_1"]})
      |> render_click()

      assert has_element?(
               view,
               ~s{div[phx-click="navigate_to_resource"][phx-value-slug="#{page_1.slug}"]}
             )

      refute has_element?(
               view,
               ~s{div[phx-click="navigate_to_resource"][phx-value-slug="#{page_5.slug}"]}
             )

      # expand unit 2/module 3 details
      view
      |> element(~s{div[role="unit_2"] div[role="card_1"]})
      |> render_click()

      assert has_element?(
               view,
               ~s{div[phx-click="navigate_to_resource"][phx-value-slug="#{page_1.slug}"]}
             )

      assert has_element?(
               view,
               ~s{div[phx-click="navigate_to_resource"][phx-value-slug="#{page_5.slug}"]}
             )
    end

    # TODO: finish this test when the handle event for the "Let's discuss" button is implemented
    @tag :skip
    test "can click on let's discuss button to open DOT AI Bot interface", %{
      conn: conn,
      user: user,
      section: section
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, _view, _html} = live(conn, live_view_learn_live_route(section.slug))
    end

    @tag :skip
    test "sees a check icon on visited pages", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      set_progress(section.id, page_1.resource_id, user.id, 1.0, page_1)
      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      # expand unit 1/module 1 details
      view
      |> element(~s{div[role="unit_1"] div[role="card_1"]})
      |> render_click()

      assert has_element?(view, ~s{div[role="page_1_details"] svg[role="visited_check_icon"]})
      assert has_element?(view, ~s{div[role="page_2_details"]})
      refute has_element?(view, ~s{div[role="page_2_details"] svg[role="visited_check_icon"]})
    end

    test "can visit a page", %{conn: conn, user: user, section: section, page_1: page_1} do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      # expand unit 1/module 1 details
      view
      |> element(~s{div[role="unit_1"] div[role="card_1"]})
      |> render_click()

      # click on page 1 to navigate to that page
      view
      |> element(~s{div[phx-click="navigate_to_resource"][phx-value-slug="#{page_1.slug}"]})
      |> render_click()

      assert_redirect(view, "/sections/#{section.slug}/page/#{page_1.slug}")
    end

    test "can see the unit schedule details considering if the instructor has already scheduled it",
         %{
           conn: conn,
           user: user,
           section: section
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      # unit 1 has been scheduled by instructor, so there must be schedule details data
      assert view
             |> element(~s{div[role="unit_1"] div[role="schedule_details"]})
             |> render() =~ "Due:\n            </span>\n            Sun, Dec 31, 2023 (8:00pm)"

      # unit 2 has not been scheduled by instructor, so there must not be a schedule details data
      assert view
             |> element(~s{div[role="unit_2"] div[role="schedule_details"]})
             |> render() =~ "Due:\n            </span>\n            not yet scheduled"
    end

    @tag :skip
    test "can see units and modules progress", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1,
      page_2: page_2
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      set_progress(section.id, page_1.resource_id, user.id, 1.0, page_1)
      set_progress(section.id, page_2.resource_id, user.id, 0.5, page_2)
      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      # unit 1 progress is 38% ((1 + 0.5 + 0.0 + 0.0) / 4)
      assert view
             |> element(~s{div[role="unit_1"] div[role="unit_1_progress"]})
             |> render() =~ "style=\"width: 38%\""

      assert view
             |> element(~s{div[role="unit_1"] div[role="unit_1_progress"]})
             |> render() =~ "font-semibold\">\n    38%\n"

      # module 1 progress is 75% ((1 + 0.5) / 2)
      assert view
             |> element(~s{div[role="unit_1"] div[role="card_1_progress"]})
             |> render() =~ "style=\"width: 75%\""
    end

    test "can see icon that identifies pages at level 2 of hierarchy (and can navigate to them)",
         %{
           conn: conn,
           user: user,
           section: section,
           page_7: page_7
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      assert has_element?(view, ~s{div[role="unit_3"] div[role="card_1"] div[role="page icon"]})

      # click on page 7 card to navigate to that page
      view
      |> element(~s{div[role="unit_3"] div[role="card_1"]})
      |> render_click()

      assert_redirect(view, "/sections/#{section.slug}/page/#{page_7.slug}")
    end

    test "can see card progress bar for modules at level 2 of hierarchy, but not for pages at level 2",
         %{
           conn: conn,
           user: user,
           section: section
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      assert has_element?(view, ~s{div[role="unit_1"] div[role="card_1_progress"]})
      refute has_element?(view, ~s{div[role="unit_3"] div[role="card_1_progress"]})
    end

    test "can see card background image if provided (if not the default one is shown)",
         %{
           conn: conn,
           user: user,
           section: section
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)

      {:ok, view, _html} = live(conn, live_view_learn_live_route(section.slug))

      assert view
             |> element(~s{div[role="unit_1"] div[role="card_1"]"})
             |> render =~ "bg-[url(&#39;module_1_custom_image_url&#39;)]"

      assert view
             |> element(~s{div[role="unit_1"] div[role="card_2"]"})
             |> render =~ "bg-[url(&#39;/images/course_default.jpg&#39;)]"
    end
  end
end
