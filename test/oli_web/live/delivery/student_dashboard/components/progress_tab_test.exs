defmodule OliWeb.Delivery.StudentDashboard.Components.ProgressTabTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections

  defp live_view_students_dashboard_route(
         section_slug,
         student_id,
         tab,
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

  defp enrolled_student_and_instructor(%{section: section, instructor: instructor}) do
    student = insert(:user)
    Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])
    Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
    %{student: student}
  end

  describe "Progress tab" do
    setup [:instructor_conn, :section_with_assessment, :enrolled_student_and_instructor]

    test "gets rendered correctly", %{
      section: section,
      conn: conn,
      student: student
    } do
      {:ok, view, _html} =
        live(conn, live_view_students_dashboard_route(section.slug, student.id, :progress))

      # Progress tab is the selected one
      assert has_element?(
               view,
               ~s{a[href="#{live_view_students_dashboard_route(section.slug, student.id, :progress)}"].border-b-2},
               "Progress"
             )

      assert has_element?(view, "p", "Not available yet")
    end
  end
end
