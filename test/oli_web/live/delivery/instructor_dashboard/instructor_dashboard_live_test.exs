defmodule OliWeb.Delivery.InstructorDashboard.InstructorDashboardLiveTest do
  use ExUnit.Case, async: false
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.InstructorDashboard
  alias Oli.InstructorDashboard.InstructorDashboardState
  alias Oli.Repo
  alias Oli.Delivery.Sections
  alias OliWeb.Delivery.InstructorDashboard.Helpers

  defp instructor_dashboard_path(section_slug, view) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      section_slug,
      view
    )
  end

  describe "user" do
    test "can not access page when it is not logged in", %{conn: conn} do
      section = insert(:section)

      redirect_path =
        "/users/log_in"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :overview))

      redirect_path =
        "/users/log_in"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :insights))

      redirect_path =
        "/users/log_in"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :manage))

      redirect_path =
        "/users/log_in"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :discussions))
    end
  end

  describe "student" do
    setup [:user_conn]

    test "can not access page", %{user: user, conn: conn} do
      section = insert(:section)
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :overview))

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :insights))

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :manage))

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :discussions))
    end
  end

  describe "instructor" do
    setup [:instructor_conn, :section_with_assessment]

    test "cannot access page if not enrolled to section", %{conn: conn, section: section} do
      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :overview))

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :insights))

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :manage))

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, instructor_dashboard_path(section.slug, :discussions))
    end

    test "ensures instructors have access to the top navigation menu bar on vertical scroll", %{
      conn: conn,
      instructor: instructor,
      section: section
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      {:ok, view, _html} = live(conn, instructor_dashboard_path(section.slug, :overview))

      assert view
             |> has_element?(".bg-delivery-instructor-dashboard-header.sticky.top-0")
    end

    test "if enrolled, can access the overview page with the course content tab as the default tab",
         %{
           instructor: instructor,
           section: section,
           conn: conn
         } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, instructor_dashboard_path(section.slug, :overview))

      assert has_element?(view, "a.active", "Course Content")
      assert has_element?(view, "a", "Students")
      refute has_element?(view, "a.active", "Students")
      assert has_element?(view, "a", "Assessment Scores")
      refute has_element?(view, "a.active", "Assessment Scores")
      assert has_element?(view, "a", "Recommended Actions")
      refute has_element?(view, "a.active", "Recommended Actions")
    end

    test "if enrolled, can access the mange page", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, ~p"/sections/#{section.slug}/manage")

      assert has_element?(view, "div", "Overview of course section details")
    end

    test "if enrolled, can access the discussion activity page", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, instructor_dashboard_path(section.slug, :discussions))

      assert has_element?(view, "h4", "Discussion Activity")
    end

    test "user is sent to the dashboard tab if an invalid tab is provided in the url param",
         %{
           conn: conn,
           instructor: instructor,
           section: section
         } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      invalid_path =
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          "invalid_tab",
          %{}
        )

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, invalid_path)

      assert redirected_path ==
               "/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=course"

      {:ok, view, _html} = live(conn, redirected_path)

      assert has_element?(view, "a.active", "Dashboard")
    end

    test "restores and persists the last viewed dashboard scope for the instructor enrollment", %{
      conn: conn,
      instructor: instructor,
      section: section
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      enrollment = Sections.get_enrollment(section.slug, instructor.id, filter_by_status: false)
      {_, containers} = Helpers.get_containers(section)
      container = hd(containers)

      {:ok, _state} =
        InstructorDashboard.upsert_state(enrollment.id, %{
          last_viewed_scope: "container:#{container.id}"
        })

      dashboard_path =
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          :dashboard
        )

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, dashboard_path)

      assert redirected_path ==
               "/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=container%3A#{container.id}"

      {:ok, view, _html} = live(conn, redirected_path)

      assert has_element?(view, "button", container.title)

      {:ok, _course_view, _html} =
        live(
          conn,
          ~p"/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=course"
        )

      assert Repo.get_by!(InstructorDashboardState, enrollment_id: enrollment.id).last_viewed_scope ==
               "course"
    end
  end

  describe "instructor: insights > dashboard tab" do
    setup [:instructor_conn, :section_with_assessment]

    test "if enrolled, can access the insights page with the dashboard tab as the default tab", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      insights_path = instructor_dashboard_path(section.slug, :insights)

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, insights_path)

      assert redirected_path ==
               "/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=course"

      {:ok, view, _html} = live(conn, redirected_path)

      assert has_element?(view, "a.active", "Dashboard")
      assert has_element?(view, "#learning-dashboard")
      assert has_element?(view, "a", "Content")
      refute has_element?(view, "a.active", "Content")
      assert has_element?(view, "a", "Learning Objectives")
      refute has_element?(view, "a.active", "Learning Objectives")
      assert has_element?(view, "a", "Scored Pages")
      refute has_element?(view, "a.active", "Scored Pages")
      assert has_element?(view, "a", "Practice Pages")
      refute has_element?(view, "a.active", "Practice Pages")
      assert has_element?(view, "a", "Surveys")
      refute has_element?(view, "a.active", "Surveys")
    end

    test "bare insights entry restores persisted dashboard scope and canonicalizes the url", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      enrollment = Sections.get_enrollment(section.slug, instructor.id, filter_by_status: false)
      {_, containers} = Helpers.get_containers(section)
      container = hd(containers)

      {:ok, _state} =
        InstructorDashboard.upsert_state(enrollment.id, %{
          last_viewed_scope: "container:#{container.id}"
        })

      insights_path = instructor_dashboard_path(section.slug, :insights)

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, insights_path)

      assert redirected_path ==
               "/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=container%3A#{container.id}"

      {:ok, view, _html} = live(conn, redirected_path)

      assert has_element?(view, "button", container.title)
    end

    test "if enrolled, can access the insights dashboard tab", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      dashboard_path =
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          :dashboard
        )

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, dashboard_path)

      {:ok, view, _html} = live(conn, redirected_path)

      assert has_element?(view, "a.active", "Dashboard")
      assert has_element?(view, "#learning-dashboard-shell")
      assert has_element?(view, "button", "Entire Course")
    end

    test "scope navigator selection from course to container patches url and persists scope", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      enrollment = Sections.get_enrollment(section.slug, instructor.id, filter_by_status: false)
      {_, containers} = Helpers.get_containers(section)
      container = hd(containers)

      dashboard_path =
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          :dashboard
        )

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, dashboard_path)

      {:ok, view, _html} = live(conn, redirected_path)

      view
      |> element("button[data-list-navigator-option='true']", container.title)
      |> render_click()

      assert_patch(
        view,
        "/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=container%3A#{container.id}"
      )

      assert Repo.get_by!(InstructorDashboardState, enrollment_id: enrollment.id).last_viewed_scope ==
               "container:#{container.id}"
    end

    test "scope navigator selection clears tile_progress page while preserving the rest", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      {_, containers} = Helpers.get_containers(section)
      container = hd(containers)

      dashboard_path =
        "/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=course&tile_progress[mode]=percent&tile_progress[threshold]=80&tile_progress[page]=3"

      {:ok, view, _html} = live(conn, dashboard_path)

      view
      |> element("button[data-list-navigator-option='true']", container.title)
      |> render_click()

      assert_patch(
        view,
        "/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=container%3A#{container.id}&tile_progress[mode]=percent&tile_progress[threshold]=80"
      )
    end

    test "scope navigator selection from container to course patches url and persists scope", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      enrollment = Sections.get_enrollment(section.slug, instructor.id, filter_by_status: false)
      {_, containers} = Helpers.get_containers(section)
      container = hd(containers)

      {:ok, _state} =
        InstructorDashboard.upsert_state(enrollment.id, %{
          last_viewed_scope: "container:#{container.id}"
        })

      dashboard_path =
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          :dashboard
        )

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, dashboard_path)

      {:ok, view, _html} = live(conn, redirected_path)

      view
      |> element("button[data-list-navigator-option='true']", "Entire Course")
      |> render_click()

      assert_patch(
        view,
        "/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=course"
      )

      assert Repo.get_by!(InstructorDashboardState, enrollment_id: enrollment.id).last_viewed_scope ==
               "course"
    end

    test "dashboard entry without persisted scope patches to the default course scope", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      dashboard_path =
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          :dashboard
        )

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, dashboard_path)

      assert redirected_path ==
               "/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=course"

      {:ok, view, _html} = live(conn, redirected_path)

      assert has_element?(view, "button", "Entire Course")
    end

    test "assessments tile patches url and scrolls when expanding from the dashboard", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      dashboard_path =
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          :dashboard
        )

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, dashboard_path)

      {:ok, view, _html} = live(conn, redirected_path)
      assessment_id = assessment_id_for_title(render(view), "Other test revision")

      view
      |> element(
        "button[phx-click='assessment_row_toggled'][phx-value-assessment_id='#{assessment_id}']"
      )
      |> render_click()

      assert_patch(
        view,
        "/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=course&tile_assessments[expanded]=#{assessment_id}"
      )

      target_id = "learning-dashboard-assessment-card-#{assessment_id}"

      assert_push_event(view, "scroll-y-to-target", %{
        id: ^target_id,
        offset: 6,
        scroll_mode: "contain",
        scroll_delay: 120,
        offset_target_id: "instructor-dashboard-header"
      })
    end

    test "assessments tile opens the draft email modal from the dashboard", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      dashboard_path =
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          :dashboard
        )

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, dashboard_path)

      {:ok, view, _html} = live(conn, redirected_path)
      assessment_id = assessment_id_for_title(render(view), "Other test revision")

      assert has_element?(view, "#learning-dashboard-assessments-tile")

      view
      |> element(
        "button[phx-click='assessment_row_toggled'][phx-value-assessment_id='#{assessment_id}']"
      )
      |> render_click()

      assert_patch(
        view,
        "/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=course&tile_assessments[expanded]=#{assessment_id}"
      )

      assert has_element?(view, "button", "Email Students Not Completed")

      view
      |> element(
        "#learning-dashboard-assessments-tile button[phx-click='open_assessment_email_modal']"
      )
      |> render_click()

      assert has_element?(view, "#student_support_email_modal_assessments_tile")
    end

    test "student support bucket selection patches the url with namespaced tile params", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      dashboard_path =
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          :dashboard
        )

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, dashboard_path)

      {:ok, view, _html} = live(conn, redirected_path)

      render_hook(view, "student_support_bucket_selected", %{"bucket_id" => "on_track"})

      assert_patch(
        view,
        "/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=course&tile_support[bucket]=on_track"
      )
    end

    test "courses with only pages render a non-interactive Entire Course navigator", %{
      instructor: instructor,
      conn: conn
    } do
      %{section: section} = Oli.Seeder.base_project_with_pages()
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      dashboard_path =
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          :dashboard
        )

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, dashboard_path)

      {:ok, view, _html} = live(conn, redirected_path)

      assert render(view) =~ "Entire Course"
      refute has_element?(view, "button", "Entire Course")
      refute has_element?(view, "#search_input")
      refute has_element?(view, "a[role='previous item link']")
      refute has_element?(view, "a[role='next item link']")
      refute has_element?(view, "#learning-dashboard-engagement-group-move")
    end

    test "dashboard entry with an invalid persisted scope falls back to the default course scope",
         %{
           instructor: instructor,
           section: section,
           conn: conn
         } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      enrollment = Sections.get_enrollment(section.slug, instructor.id, filter_by_status: false)

      {:ok, _state} =
        InstructorDashboard.upsert_state(enrollment.id, %{
          last_viewed_scope: "container:999999"
        })

      dashboard_path =
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          :dashboard
        )

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, dashboard_path)

      assert redirected_path ==
               "/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=course"
    end

    test "dashboard entry with an invalid url scope canonicalizes to the default course scope", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      invalid_dashboard_path =
        ~p"/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=inexistente"

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, invalid_dashboard_path)

      assert redirected_path ==
               "/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=course"
    end

    test "toggle collapse persists and restores section expansion state", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      enrollment = Sections.get_enrollment(section.slug, instructor.id, filter_by_status: false)

      dashboard_path =
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          :dashboard
        )

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, dashboard_path)

      {:ok, view, _html} = live(conn, redirected_path)

      view
      |> element("#learning-dashboard-content-group-toggle")
      |> render_click()

      refute has_element?(view, "#learning-dashboard-content-group-content")

      assert Repo.get_by!(InstructorDashboardState, enrollment_id: enrollment.id).collapsed_section_ids ==
               ["content"]

      {:ok, restored_view, _html} = live(conn, redirected_path)

      refute has_element?(restored_view, "#learning-dashboard-content-group-content")
    end

    test "reorder persists the stable section order for the instructor enrollment", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      enrollment = Sections.get_enrollment(section.slug, instructor.id, filter_by_status: false)

      dashboard_path =
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          :dashboard
        )

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, dashboard_path)

      {:ok, view, _html} = live(conn, redirected_path)

      view
      |> element("#learning-dashboard-content-group")
      |> render_hook("dashboard_sections_reordered", %{section_ids: ["content", "engagement"]})

      html = render(view)

      assert html =~
               ~r/learning-dashboard-content-group.*learning-dashboard-engagement-group/s

      assert Repo.get_by!(InstructorDashboardState, enrollment_id: enrollment.id).section_order ==
               ["content", "engagement"]
    end

    test "invalid reorder payload is rejected and keeps the previous stable order", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      enrollment = Sections.get_enrollment(section.slug, instructor.id, filter_by_status: false)

      dashboard_path =
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          :dashboard
        )

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, dashboard_path)

      {:ok, view, _html} = live(conn, redirected_path)

      view
      |> element("#learning-dashboard-content-group")
      |> render_hook("dashboard_sections_reordered", %{section_ids: ["content"]})

      assert render(view) =~ "Invalid dashboard section order."

      assert Repo.get_by!(InstructorDashboardState, enrollment_id: enrollment.id).section_order ==
               []
    end

    test "persists section tile resize state for desktop tile groups", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      enrollment = Sections.get_enrollment(section.slug, instructor.id, filter_by_status: false)

      dashboard_path =
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          :dashboard
        )

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, dashboard_path)

      {:ok, view, _html} = live(conn, redirected_path)

      view
      |> element("#learning-dashboard-engagement-group-tiles")
      |> render_hook("dashboard_section_resized", %{section_id: "engagement", split: 58})

      assert render(view) =~ ~s(data-dashboard-section-split="58")

      assert Repo.get_by!(InstructorDashboardState, enrollment_id: enrollment.id).section_tile_layouts ==
               %{"engagement" => %{"split" => 58}, "content" => %{"split" => 43}}
    end

    test "courses without objectives or graded assessments omit the content section", %{
      instructor: instructor,
      conn: conn
    } do
      %{section: section} = Oli.Seeder.base_project_with_pages()
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      dashboard_path =
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          :dashboard
        )

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, dashboard_path)

      {:ok, view, _html} = live(conn, redirected_path)

      refute has_element?(view, "#learning-dashboard-content-group")
      assert has_element?(view, "#learning-dashboard-engagement-group")
    end

    test "single visible content tile renders the section in single-column layout", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      dashboard_path =
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          :dashboard
        )

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, dashboard_path)

      {:ok, view, _html} = live(conn, redirected_path)

      assert has_element?(
               view,
               "#learning-dashboard-content-group [data-section-layout='single']"
             )

      assert has_element?(view, "#learning-dashboard-assessments-tile")
      refute has_element?(view, "#learning-dashboard-objectives-placeholder")
    end

    test "root instructor dashboard route redirects to insights dashboard", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      conn = get(conn, ~p"/sections/#{section.slug}/instructor_dashboard")

      assert redirected_to(conn) ==
               "/sections/#{section.slug}/instructor_dashboard/insights/dashboard"
    end

    test "user is sent to the dashboard tab if an invalid tab is provided in the url param",
         %{
           conn: conn,
           instructor: instructor,
           section: section
         } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      invalid_path =
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          "invalid_tab",
          %{}
        )

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, invalid_path)

      assert redirected_path ==
               "/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=course"

      {:ok, view, _html} = live(conn, redirected_path)

      assert has_element?(view, "a.active", "Dashboard")
    end

    test "restores and persists the last viewed dashboard scope for the instructor enrollment", %{
      conn: conn,
      instructor: instructor,
      section: section
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      enrollment = Sections.get_enrollment(section.slug, instructor.id, filter_by_status: false)
      {_, containers} = Helpers.get_containers(section)
      container = hd(containers)

      {:ok, _state} =
        InstructorDashboard.upsert_state(enrollment.id, %{
          last_viewed_scope: "container:#{container.id}"
        })

      dashboard_path =
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          :dashboard
        )

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, dashboard_path)

      assert redirected_path ==
               "/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=container%3A#{container.id}"

      {:ok, view, _html} = live(conn, redirected_path)

      assert has_element?(view, "button", container.title)

      {:ok, _course_view, _html} =
        live(
          conn,
          ~p"/sections/#{section.slug}/instructor_dashboard/insights/dashboard?dashboard_scope=course"
        )

      assert Repo.get_by!(InstructorDashboardState, enrollment_id: enrollment.id).last_viewed_scope ==
               "course"
    end
  end

  describe "instructor: insights > dashboard tab with objectives" do
    setup [:instructor_conn, :create_full_project_with_objectives]

    test "renders the challenging objectives tile when the section has objectives", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      dashboard_path =
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          :dashboard
        )

      assert {:error, {:live_redirect, %{to: redirected_path, flash: %{}}}} =
               live(conn, dashboard_path)

      {:ok, view, _html} = live(conn, redirected_path)

      assert has_element?(view, "#learning-dashboard-content-group")
      assert has_element?(view, "[id^='learning-dashboard-challenging-objectives-']")
      assert has_element?(view, "h3", "Challenging Objectives")
    end
  end

  defp assessment_id_for_title(html, title) do
    regex =
      ~r/phx-value-assessment_id="(?<id>\d+)".*?aria-label="Expand assessment #{Regex.escape(title)}"/s

    case Regex.named_captures(regex, html) do
      %{"id" => id} -> id
      _ -> flunk("Could not find assessment id for title #{inspect(title)}")
    end
  end
end
