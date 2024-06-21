defmodule OliWeb.Delivery.InstructorDashboard.Overview.RecommendedActionsTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Ecto.Query, warn: false
  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Repo

  defp instructor_course_content_path(section_slug) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      section_slug,
      :overview,
      :recommended_actions
    )
  end

  defp enroll_instructor(%{section: section, instructor: instructor}) do
    enroll_user_to_section(instructor, section, :context_instructor)

    {:ok, []}
  end

  defp add_schedule(section_id) do
    {:ok, start_date} = DateTime.from_naive(~N[2023-05-24 00:00:00], "UTC")

    Oli.Delivery.Sections.SectionResource
    |> where([sr], sr.section_id == ^section_id)
    |> select([sr], sr)
    |> limit(1)
    |> Repo.one()
    |> Oli.Delivery.Sections.SectionResource.changeset(%{start_date: start_date})
    |> Repo.update()
  end

  describe "Instructor dashboard overview - recommended_actions tab" do
    setup [:instructor_conn, :basic_section, :enroll_instructor]

    test "renders a \"no actions\" when no recommended actions exist", %{
      conn: conn,
      section: section
    } do
      add_schedule(section.id)

      {:ok, view, _html} = live(conn, instructor_course_content_path(section.slug))

      assert has_element?(view, "span", "No action needed")
    end

    test "does not render the \"soft scheduling\" action when necessary", %{
      conn: conn,
      section: section
    } do
      add_schedule(section.id)

      assert Oli.Delivery.RecommendedActions.section_has_scheduled_resources?(section.id)

      {:ok, view, _html} = live(conn, instructor_course_content_path(section.slug))

      refute has_element?(view, "h4", "Scheduling")
      refute has_element?(view, "span", "You have not defined a schedule for your course content")
    end

    test "renders the \"soft scheduling\" action when necessary (for example, after a new course section has just been created)",
         %{
           conn: conn,
           section: section
         } do
      {:ok, view, _html} = live(conn, instructor_course_content_path(section.slug))

      refute Oli.Delivery.RecommendedActions.section_has_scheduled_resources?(section.id)

      assert has_element?(view, "h4", "Scheduling")
      assert has_element?(view, "span", "You have not defined a schedule for your course content")
    end

    test "renders the \"pending approval posts\" action when necessary", %{
      conn: conn,
      section: section,
      section_page: section_page
    } do
      user = insert(:user)

      insert(:post,
        section: section,
        resource: section_page.resource,
        user: user,
        status: :submitted
      )

      {:ok, view, _html} = live(conn, instructor_course_content_path(section.slug))

      assert has_element?(view, "h4", "Approve Pending Posts")

      assert has_element?(
               view,
               "span",
               "You have 1 discussion post that is pending your approval"
             )
    end

    test "redirects to discussion activity tab when click to approve pending posts", %{
      conn: conn,
      section: section,
      section_page: section_page
    } do
      user = insert(:user)

      # create a pending post
      post =
        insert(:post,
          content: %{message: "Example Post Content 1"},
          section: section,
          resource: section_page.resource,
          user: user,
          status: :submitted
        )

      # access to recommended actions tab to see the pending post
      {:ok, view, _html} = live(conn, instructor_course_content_path(section.slug))

      assert has_element?(view, "h4", "Approve Pending Posts")

      assert has_element?(
               view,
               "span",
               "You have 1 discussion post that is pending your approval"
             )

      # click to approve pending posts (redirect to discussion activity tab)
      view
      |> element(
        "div[id=\"recommended_actions\"] > a[href=\"/sections/#{section.slug}/instructor_dashboard/discussions\"]"
      )
      |> render_click()

      # check if the pending post is displayed in the discussion activity tab
      {:ok, view, _html} =
        live(conn, ~p"/sections/#{section.slug}/instructor_dashboard/discussions")

      assert has_element?(view, "h4", "Discussion Activity")
      assert has_element?(view, "p[class=\"torus-p\"]", post.content.message)
    end

    test "renders the \"score questions\" action when necessary", %{
      conn: conn,
      section: section,
      section_page: section_page
    } do
      user = insert(:user)

      # access and attempt for current section
      resource_access =
        insert(:resource_access, user: user, section: section, resource: section_page.resource)

      resource_attempt = insert(:resource_attempt, resource_access: resource_access)

      insert(:activity_attempt,
        resource_attempt: resource_attempt,
        resource: section_page.resource,
        revision: section_page,
        lifecycle_state: :submitted
      )

      # access and attempt for another section with same page resource
      another_section = insert(:section)

      resource_access =
        insert(:resource_access,
          user: user,
          section: another_section,
          resource: section_page.resource
        )

      resource_attempt = insert(:resource_attempt, resource_access: resource_access)

      insert(:activity_attempt,
        resource_attempt: resource_attempt,
        resource: section_page.resource,
        revision: section_page,
        lifecycle_state: :submitted
      )

      {:ok, view, _html} = live(conn, instructor_course_content_path(section.slug))

      assert has_element?(view, "h4", "Score questions")

      # the pending score of the other section should not be counted
      refute has_element?(
               view,
               "span",
               "You have 2 questions that are awaiting your manual scoring"
             )

      assert has_element?(
               view,
               "span",
               "You have 1 question that is awaiting your manual scoring"
             )
    end

    test "renders the \"pending updates\" action when necessary", %{
      conn: conn,
      section: section,
      project: project
    } do
      insert(:publication, project: project, published: DateTime.utc_now())

      {:ok, view, _html} = live(conn, instructor_course_content_path(section.slug))

      assert has_element?(view, "h4", "Pending course update")

      assert has_element?(
               view,
               "span",
               "There are available course content updates that you have not accepted"
             )
    end

    test "renders the \"remind student of deadlines\" action when necessary", %{
      conn: conn,
      section: section,
      section_page: section_page
    } do
      set_schedule_for_page(10, section_page, section.id)

      {:ok, view, _html} = live(conn, instructor_course_content_path(section.slug))

      assert has_element?(view, "h4", "Remind Students of Deadlines")

      assert has_element?(
               view,
               "span",
               "There are assessments due soon, review and remind students"
             )
    end

    test "\"remind student of deadlines\" action redirects to Scored Activities tab correctly", %{
      conn: conn,
      section: section,
      section_page: section_page
    } do
      set_schedule_for_page(10, section_page, section.id)

      {:ok, view, _html} = live(conn, instructor_course_content_path(section.slug))

      assert has_element?(view, "h4", "Remind Students of Deadlines")

      assert has_element?(
               view,
               "span",
               "There are assessments due soon, review and remind students"
             )

      assert has_element?(
               view,
               "a[href=\"/sections/#{section.slug}/instructor_dashboard/insights/scored_activities\"]"
             )

      element(
        view,
        "a[href=\"/sections/#{section.slug}/instructor_dashboard/insights/scored_activities\"]"
      )
      |> render_click()

      assert_redirected(
        view,
        ~p"/sections/#{section.slug}/instructor_dashboard/insights/scored_activities"
      )
    end

    test "does not render the \"remind student of deadlines\" action when not necessary", %{
      conn: conn,
      section: section,
      section_page: section_page
    } do
      set_schedule_for_page(25, section_page, section.id)

      {:ok, view, _html} = live(conn, instructor_course_content_path(section.slug))

      refute has_element?(view, "h4", "Remind Students of Deadlines")

      refute has_element?(
               view,
               "span",
               "There are assessments due soon, review and remind students"
             )
    end
  end

  defp set_schedule_for_page(hours, section_page, section_id) do
    end_date = DateTime.utc_now() |> DateTime.add(hours, :hour) |> DateTime.truncate(:second)

    section_page
    |> Ecto.Changeset.change(%{graded: true})
    |> Repo.update()

    Oli.Delivery.Sections.SectionResource
    |> where([sr], sr.resource_id == ^section_page.resource.id and sr.section_id == ^section_id)
    |> select([sr], sr)
    |> limit(1)
    |> Repo.one()
    |> Ecto.Changeset.change(%{scheduling_type: :due_by, end_date: end_date})
    |> Repo.update()
  end
end
