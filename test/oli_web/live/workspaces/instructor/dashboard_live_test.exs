defmodule OliWeb.Workspaces.Instructor.DashboardLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections

  describe "instructor dashboard" do
    setup [:instructor_conn]

    test "renders sub-menu and exit section button", %{conn: conn, instructor: instructor} do
      section = insert(:section, %{open_and_free: true})
      user_id = instructor.id

      Sections.enroll(user_id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, ~p"/workspaces/instructor/#{section.slug}/overview")

      data_expected = %{
        1 =>
          {"Course Content",
           "/workspaces/instructor/#{section.slug}/overview/course_content?sidebar_expanded=true"},
        2 =>
          {"Students",
           "/workspaces/instructor/#{section.slug}/overview/students?sidebar_expanded=true"},
        3 =>
          {"Quiz Scores",
           "/workspaces/instructor/#{section.slug}/overview/quiz_scores?sidebar_expanded=true"},
        4 =>
          {"Recommended Actions",
           "/workspaces/instructor/#{section.slug}/overview/recommended_actions?sidebar_expanded=true"},
        5 =>
          {"Content",
           "/workspaces/instructor/#{section.slug}/insights/content?sidebar_expanded=true"},
        6 =>
          {"Learning Objectives",
           "/workspaces/instructor/#{section.slug}/insights/learning_objectives?sidebar_expanded=true"},
        7 =>
          {"Scored Activities",
           "/workspaces/instructor/#{section.slug}/insights/scored_activities?sidebar_expanded=true"},
        8 =>
          {"Practice Activities",
           "/workspaces/instructor/#{section.slug}/insights/practice_activities?sidebar_expanded=true"},
        9 =>
          {"Surveys",
           "/workspaces/instructor/#{section.slug}/insights/surveys?sidebar_expanded=true"},
        10 => {"Manage", "/workspaces/instructor/#{section.slug}/manage?sidebar_expanded=true"},
        11 =>
          {"Activity", "/workspaces/instructor/#{section.slug}/activity?sidebar_expanded=true"}
      }

      data_obtained =
        view
        |> render()
        |> Floki.find("#sub_menu a")
        |> Enum.reduce({0, %{}}, fn anchor, {index, acc} ->
          text = String.trim(Floki.text(anchor))
          [href] = Floki.attribute(anchor, "href")

          {index + 1, Map.put(acc, index + 1, {text, href})}
        end)
        |> elem(1)

      assert data_expected === data_obtained

      assert "Exit Section" =
               view
               |> render()
               |> Floki.find("#exit_course_button")
               |> Floki.text()
               |> String.trim()
    end
  end
end
