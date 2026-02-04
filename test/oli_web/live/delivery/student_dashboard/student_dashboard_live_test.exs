defmodule OliWeb.Delivery.StudentDashboard.StudentDashboardLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections

  defp live_view_students_dashboard_route(
         section_slug,
         student_id,
         tab \\ :content,
         params \\ %{}
       ) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.StudentDashboard.StudentDashboardLive,
      section_slug,
      student_id,
      tab,
      params
    )
  end

  defp enrolled_student(%{section: section}) do
    student = insert(:user)
    Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])
    %{student: student}
  end

  describe "user" do
    test "can not access page when it is not logged in", %{conn: conn} do
      section = insert(:section)
      student = insert(:user)

      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])

      redirect_path =
        "/users/log_in"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_students_dashboard_route(section.slug, student.id))
    end
  end

  describe "student" do
    setup [:user_conn]

    test "can not access page", %{user: user, conn: conn} do
      section = insert(:section)
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_students_dashboard_route(section.slug, user.id))
    end
  end

  describe "instructor" do
    setup [:instructor_conn, :section_with_assessment, :enrolled_student]

    test "cannot access page if not enrolled to section", %{
      conn: conn,
      section: section,
      student: student
    } do
      redirect_path = "/unauthorized"

      assert {:error, {:redirect, %{to: ^redirect_path}}} =
               live(conn, live_view_students_dashboard_route(section.slug, student.id))
    end

    test "can access page if enrolled to section", %{
      instructor: instructor,
      section: section,
      conn: conn,
      student: student
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} =
        live(conn, live_view_students_dashboard_route(section.slug, student.id))

      # Content tab is the selected one
      assert has_element?(
               view,
               ~s{a[href="#{live_view_students_dashboard_route(section.slug, student.id, :content)}"].border-b-2},
               "Content"
             )

      assert has_element?(view, "button[id=\"filter_units_button\"]", "Units")
    end

    test "can see the student details card correctly", %{
      instructor: instructor,
      student: student,
      conn: conn
    } do
      %{section: section, survey: survey, survey_questions: survey_questions} =
        section_with_survey()

      complete_student_survey(student, section, survey, survey_questions)

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} =
        live(conn, live_view_students_dashboard_route(section.slug, student.id))

      student_details_card = element(view, "#student_details_card")
      assert render(student_details_card) =~ "Experience"
      assert render(student_details_card) =~ "A lot"
    end

    test "breadcrumbs get render correctly when coming from the instructor dashboard", %{
      instructor: instructor,
      student: student,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, _view, html} =
        live(conn, live_view_students_dashboard_route(section.slug, student.id))

      assert html =~
               ~s(<a href="/sections/#{section.slug}/instructor_dashboard/overview/students">Student reports</a>)

      assert html =~ ~s(#{student.name} information)
    end

    test "renders student progress calculation modal in the student overview view", %{
      instructor: instructor,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} =
        live(conn, ~p"/sections/#{section.slug}/instructor_dashboard/overview/students")

      # Button that triggers a tooltip
      assert has_element?(
               view,
               "button[xphx-mouseover='[[\"show\",{\"display\":\"flex\",\"to\":\"#student_progress_tooltip\"}]]']"
             )

      # Renders correct column title
      assert has_element?(view, "th[phx-value-sort_by='progress']", "Student Progress")

      # Link that triggers the opening of the modal
      assert view |> has_element?("button#student_progress_tooltip_link", "Learn more")

      # Modal component for rendering the student progress calculation modal dialog
      assert view |> has_element?("div#student_progress_calculation_modal")
    end

    test "renders student progress calculation modal in the student reports view", %{
      instructor: instructor,
      student: student,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} =
        live(conn, live_view_students_dashboard_route(section.slug, student.id))

      # Button that triggers a tooltip
      assert has_element?(
               view,
               "button[xphx-mouseover='[[\"show\",{\"display\":\"flex\",\"to\":\"#student_progress_tooltip\"}]]']"
             )

      # Renders correct column title
      assert has_element?(
               view,
               "th[phx-value-sort_by='student_completion']",
               "Student Progress"
             )

      # Link that triggers the opening of the modal
      assert view |> has_element?("button#student_progress_tooltip_link", "Learn more")

      # Modal component for rendering the student progress calculation modal dialog
      assert view |> has_element?("div#student_progress_calculation_modal")
    end

    test "handle_info selected_card_containers updates URL params when card is selected", %{
      instructor: instructor,
      student: student,
      section: section,
      conn: conn
    } do
      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} =
        live(conn, live_view_students_dashboard_route(section.slug, student.id, :content))

      # Verify the card is initially not selected
      card_html_before =
        view
        |> element("div[phx-value-selected='high_progress_low_proficiency']")
        |> render()

      # Check that selected state classes are not present
      # The selected background class should not be present
      refute card_html_before =~ "bg-[#F2F9FF]"

      # The selected outline class should not be present (hover:outline-[#006CD9] is in base classes)
      refute String.contains?(card_html_before, "outline-[#006CD9]") and
               not String.contains?(card_html_before, "hover:outline-[#006CD9]")

      # Verify default outline is present instead
      assert card_html_before =~ "outline-gray-300"

      # Send the selected_card_containers message
      # to simulate the user clicking on the card
      send(view.pid, {:selected_card_containers, :high_progress_low_proficiency})

      # The handle_info should trigger a push_patch
      expected_path =
        "/sections/#{section.slug}/student_dashboard/#{student.id}/content?active_tab=content&section_slug=#{section.slug}&selected_card_value=high_progress_low_proficiency&student_id=#{student.id}"

      assert_patch(view, expected_path)

      # Verify the card is marked as selected
      card_html =
        view
        |> element("div[phx-value-selected='high_progress_low_proficiency']")
        |> render()

      assert card_html =~ "bg-[#F2F9FF]"
      assert card_html =~ "outline-[#006CD9]"
    end
  end

  def section_with_survey() do
    elem(section_with_survey(nil), 1) |> Enum.into(%{})
  end
end
