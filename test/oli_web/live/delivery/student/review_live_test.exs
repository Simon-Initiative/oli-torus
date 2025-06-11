defmodule OliWeb.Delivery.Student.ReviewLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory
  import Ecto.Query, warn: false

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Resources.ResourceType
  alias OliWeb.Delivery.Student.Utils

  @default_selected_view :gallery

  defp create_attempt(student, section, revision) do
    resource_access =
      insert(:resource_access, %{
        user: student,
        section: section,
        resource: revision.resource,
        score: 5,
        out_of: 10
      })

    resource_attempt =
      insert(:resource_attempt, %{
        resource_access: resource_access,
        revision: revision,
        date_evaluated: DateTime.utc_now(),
        score: 5,
        out_of: 10,
        content: %{model: []},
        lifecycle_state: :active
      })

    resource_attempt
  end

  defp create_elixir_project(_) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # revisions...

    ## objectives...
    objective_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("objective"),
        title: "this is the first objective"
      )

    objective_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("objective"),
        title: "this is the second objective"
      )

    ## pages...
    page_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 1",
        duration_minutes: 10,
        content: %{
          model: [
            %{
              id: "158828742",
              type: "content",
              children: [
                %{
                  id: "3371710400",
                  type: "p",
                  children: [%{text: "Here's some test page content"}]
                }
              ]
            }
          ]
        },
        graded: true
      )

    page_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 2",
        duration_minutes: 15,
        objectives: %{
          "attached" => [objective_1_revision.resource_id, objective_2_revision.resource_id]
        },
        graded: true
      )

    page_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 3",
        duration_minutes: 5,
        graded: true
      )

    graded_adaptive_page_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        graded: true,
        max_attempts: 5,
        title: "Graded Adaptive Page",
        # purpose: :foundation,
        content: %{
          "model" => [],
          "advancedDelivery" => true,
          "displayApplicationChrome" => false,
          "additionalStylesheets" => [
            "/css/delivery_adaptive_themes_default_light.css"
          ]
        }
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
                  text: "Throughout this unit you will learn how to use this course."
                }
              ]
            }
          ]
        }
      })

    module_2_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_3_revision.resource_id, graded_adaptive_page_revision.resource_id],
        title: "The second module is awesome!",
        poster_image: "module_2_custom_image_url",
        intro_content: %{
          children: [
            %{
              type: "p",
              children: [
                %{
                  text: "Thoughout this unit you will have a lot of fun."
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
        children: [module_1_revision.resource_id, module_2_revision.resource_id],
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
        objective_1_revision,
        objective_2_revision,
        page_1_revision,
        page_2_revision,
        page_3_revision,
        graded_adaptive_page_revision,
        module_1_revision,
        module_2_revision,
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
        start_date: ~U[2023-10-30 20:00:00Z],
        analytics_version: :v2
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section)

    # schedule start and end date for unit 1 section resource
    Sections.get_section_resource(section.id, unit_1_revision.resource_id)
    |> Sections.update_section_resource(%{
      start_date: ~U[2023-10-31 20:00:00Z],
      end_date: ~U[2023-12-31 20:00:00Z]
    })

    # schedule start and end date for page 2 section resource
    Sections.get_section_resource(section.id, page_2_revision.resource_id)
    |> Sections.update_section_resource(%{
      start_date: ~U[2023-11-10 20:00:00Z],
      end_date: ~U[2023-11-14 20:00:00Z]
    })

    %{
      objective_1: objective_1_revision,
      objective_2: objective_2_revision,
      section: section,
      page_1: page_1_revision,
      page_2: page_2_revision,
      page_3: page_3_revision,
      graded_adaptive_page_revision: graded_adaptive_page_revision,
      module_1: module_1_revision,
      module_2: module_2_revision,
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

      attempt = create_attempt(student, section, page_1)

      {:error, {:redirect, %{to: redirect_path}}} =
        live(conn, Utils.review_live_path(section.slug, page_1.slug, attempt.attempt_guid))

      assert redirect_path ==
               "/users/log_in"
    end
  end

  describe "student" do
    setup [:user_conn, :create_elixir_project]

    test "can not access when not enrolled to course", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1
    } do
      attempt = create_attempt(user, section, page_1)

      {:error, {:redirect, %{to: redirect_path, flash: _flash_msg}}} =
        live(conn, Utils.review_live_path(section.slug, page_1.slug, attempt.attempt_guid))

      assert redirect_path == "/sections/#{section.slug}/enroll"
    end

    test "can not access when review is not allowed", %{
      conn: conn,
      section: section,
      page_1: page_1,
      user: user
    } do
      # Disallow review submission
      insert(:delivery_setting, %{
        section: section,
        user: user,
        resource: page_1.resource,
        review_submission: :disallow
      })

      Sections.mark_section_visited_for_student(section, user)
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      attempt = create_attempt(user, section, page_1)

      {:error, {:redirect, %{to: redirect_path}}} =
        live(conn, Utils.review_live_path(section.slug, page_1.slug, attempt.attempt_guid))

      assert redirect_path == Utils.learn_live_path(section.slug)
    end

    test "can not access when the current user did not originate the attempt", %{
      conn: conn,
      section: section,
      page_1: page_1,
      user: user
    } do
      # another student is enrolled and has an attempt
      another_student = insert(:user)
      Sections.enroll(another_student.id, section.id, [ContextRoles.get_role(:context_learner)])
      another_student_attempt = create_attempt(another_student, section, page_1)

      # current user is enrolled and has an attempt
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      create_attempt(user, section, page_1)

      # we visit the student attempt as a different user
      {:error, {:redirect, %{to: redirect_path}}} =
        live(
          conn,
          Utils.review_live_path(
            section.slug,
            page_1.slug,
            another_student_attempt.attempt_guid
          )
        )

      assert redirect_path == Utils.learn_live_path(section.slug)
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
      attempt = create_attempt(user, section, page_1)

      {:ok, view, _html} =
        live(conn, Utils.review_live_path(section.slug, page_1.slug, attempt.attempt_guid))

      ensure_content_is_visible(view)
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

    test "can see page info on header", %{
      conn: conn,
      user: user,
      section: section,
      objective_1: o1,
      objective_2: o2,
      page_2: page_2
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)
      attempt = create_attempt(user, section, page_2)

      {:ok, view, _html} =
        live(conn, Utils.review_live_path(section.slug, page_2.slug, attempt.attempt_guid))

      ensure_content_is_visible(view)

      assert has_element?(view, ~s{div[role="container label"]}, "Module 1")
      assert has_element?(view, ~s{div[role="page numbering index"]}, "2.")
      assert has_element?(view, ~s{div[role="page title"]}, "Page 2")
      assert has_element?(view, ~s{div[role="page read time"]}, "15")
      assert has_element?(view, ~s{div[role="page schedule"]}, "Tue Nov 14, 2023")

      assert has_element?(
               view,
               ~s{div[role="objective #{o1.resource_id}"]},
               "this is the first objective"
             )

      assert has_element?(
               view,
               ~s{div[role="objective #{o2.resource_id}"]},
               "this is the second objective"
             )
    end

    test "back to summary screen button redirects to the prologue page", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)
      attempt = create_attempt(user, section, page_1)

      request_path = Utils.learn_live_path(section.slug, target_resource_id: page_1.resource_id)

      {:ok, view, _html} =
        live(
          conn,
          Utils.review_live_path(section.slug, page_1.slug, attempt.attempt_guid,
            request_path: request_path
          )
        )

      ensure_content_is_visible(view)

      view
      |> element(~s{a[role="back_to_summary_link"]})
      |> render_click

      assert_redirected(
        view,
        Utils.lesson_live_path(section.slug, page_1.slug, request_path: request_path)
      )
    end

    test "can navigate between pages and updates references in the request path", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1,
      page_2: page_2
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)
      attempt = create_attempt(user, section, page_1)

      {:ok, view, _html} =
        live(conn, Utils.review_live_path(section.slug, page_1.slug, attempt.attempt_guid))

      ensure_content_is_visible(view)

      view
      |> element(~s{div[role="next_page"] a})
      |> render_click

      # It redirects to the next page, but still referencing the targeted Learn view in the URL with the next page resource
      request_path =
        Utils.learn_live_path(section.slug,
          target_resource_id: page_2.resource_id,
          selected_view: @default_selected_view
        )

      assert_redirected(
        view,
        Utils.lesson_live_path(section.slug, page_2.slug,
          request_path: request_path,
          selected_view: @default_selected_view
        )
      )
    end

    test "can navigate between pages and keeps the request path when it is not the learn view", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1,
      page_2: page_2
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)
      attempt = create_attempt(user, section, page_1)

      # when the request path is not the learn view, it keeps it when navigating between pages
      request_path = ~p"/sections/#{section.slug}/student_schedule"

      {:ok, view, _html} =
        live(
          conn,
          Utils.review_live_path(section.slug, page_1.slug, attempt.attempt_guid,
            request_path: request_path,
            selected_view: @default_selected_view
          )
        )

      ensure_content_is_visible(view)

      view
      |> element(~s{div[role="next_page"] a})
      |> render_click

      assert_redirected(
        view,
        Utils.lesson_live_path(section.slug, page_2.slug,
          request_path: request_path,
          selected_view: @default_selected_view
        )
      )
    end

    test "redirects to the learn page when the next or previous page corresponds to a container",
         %{
           conn: conn,
           user: user,
           section: section,
           page_2: page_2,
           page_3: page_3,
           module_2: module_2
         } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)
      attempt = create_attempt(user, section, page_2)
      _attempt_2 = create_attempt(user, section, page_3)

      # next page is a container
      {:ok, view, _html} =
        live(
          conn,
          Utils.review_live_path(section.slug, page_2.slug, attempt.attempt_guid,
            selected_view: @default_selected_view
          )
        )

      ensure_content_is_visible(view)

      view
      |> element(~s{div[role="next_page"] a})
      |> render_click

      assert_redirected(
        view,
        Utils.learn_live_path(section.slug,
          target_resource_id: module_2.resource_id,
          selected_view: @default_selected_view
        )
      )

      # previous page is a container
      {:ok, view, _html} =
        live(
          conn,
          Utils.lesson_live_path(section.slug, page_3.slug, selected_view: @default_selected_view)
        )

      ensure_content_is_visible(view)

      view
      |> element(~s{div[role="prev_page"] a})
      |> render_click

      assert_redirected(
        view,
        Utils.learn_live_path(section.slug,
          target_resource_id: module_2.resource_id,
          selected_view: @default_selected_view
        )
      )
    end

    test "back link returns to the learn page", %{
      conn: conn,
      user: user,
      section: section,
      page_1: page_1
    } do
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      Sections.mark_section_visited_for_student(section, user)
      attempt = create_attempt(user, section, page_1)

      request_path = Utils.learn_live_path(section.slug, target_resource_id: page_1.resource_id)

      {:ok, view, _html} =
        live(
          conn,
          Utils.review_live_path(section.slug, page_1.slug, attempt.attempt_guid,
            request_path: request_path
          )
        )

      ensure_content_is_visible(view)

      view
      |> element(~s{div[role="back_link"] a})
      |> render_click

      assert_redirected(
        view,
        request_path
      )
    end
  end

  describe "instructor" do
    setup [:instructor_conn, :create_elixir_project]

    test "can access to adaptive page review", %{
      conn: conn,
      instructor: instructor,
      section: section,
      graded_adaptive_page_revision: graded_adaptive_page_revision
    } do
      user = insert(:user)

      Sections.mark_section_visited_for_student(section, user)
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      attempt = create_attempt(user, section, graded_adaptive_page_revision)

      initial_path =
        Utils.review_live_path(
          section.slug,
          graded_adaptive_page_revision.slug,
          attempt.attempt_guid
        )

      conn = get(conn, initial_path)

      assert redirected_to(conn, 302) =~
               "/sections/#{section.slug}/adaptive_lesson/#{graded_adaptive_page_revision.slug}/attempt/#{attempt.attempt_guid}/review"

      conn =
        recycle(conn)
        |> log_in_user(instructor)

      conn =
        get(
          conn,
          "/sections/#{section.slug}/adaptive_lesson/#{graded_adaptive_page_revision.slug}/attempt/#{attempt.attempt_guid}/review"
        )

      assert html_response(conn, 200) =~ "Graded Adaptive Page"
    end
  end

  describe "admin" do
    setup [:admin_conn, :create_elixir_project]

    test "can access to adaptive page review", %{
      conn: conn,
      section: section,
      graded_adaptive_page_revision: graded_adaptive_page_revision,
      admin: admin
    } do
      user = insert(:user)

      Sections.mark_section_visited_for_student(section, user)

      attempt = create_attempt(user, section, graded_adaptive_page_revision)

      initial_path =
        Utils.review_live_path(
          section.slug,
          graded_adaptive_page_revision.slug,
          attempt.attempt_guid
        )

      conn = get(conn, initial_path)

      assert redirected_to(conn, 302) =~
               "/sections/#{section.slug}/adaptive_lesson/#{graded_adaptive_page_revision.slug}/attempt/#{attempt.attempt_guid}/review"

      conn =
        recycle(conn)
        |> log_in_author(admin)

      conn =
        get(
          conn,
          "/sections/#{section.slug}/adaptive_lesson/#{graded_adaptive_page_revision.slug}/attempt/#{attempt.attempt_guid}/review"
        )

      assert html_response(conn, 200) =~ "Graded Adaptive Page"
    end
  end

  defp ensure_content_is_visible(view) do
    # the content of the page will not be rendered until the socket is connected
    # and the client side confirms that the scripts are loaded
    view
    |> element("#eventIntercept")
    |> render_hook("survey_scripts_loaded", %{"loaded" => true})
  end
end
