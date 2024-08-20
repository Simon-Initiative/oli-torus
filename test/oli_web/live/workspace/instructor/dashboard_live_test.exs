defmodule OliWeb.Workspace.Instructor.DashboardLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections

  describe "instructor dashboard" do
    setup [:instructor_conn]

    test "renders sub-menu and exit section button", %{conn: conn} do
      section = insert(:section, %{open_and_free: true})
      user_id = conn.assigns.current_user.id

      Sections.enroll(user_id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, ~p"/workspaces/instructor/#{section.slug}/overview")

      common = "/workspaces/instructor/#{section.slug}"
      url_params = "?sidebar_expanded=true"

      data_expected =
        %{
          1 => {"Course Content", "#{common}/overview/course_content#{url_params}"},
          2 => {"Students", "#{common}/overview/students#{url_params}"},
          3 => {"Content", "#{common}/insights/content#{url_params}"},
          4 => {"Learning Objectives", "#{common}/insights/learning_objectives#{url_params}"},
          5 => {"Scored Activities", "#{common}/insights/scored_activities#{url_params}"},
          6 => {"Practice Activities", "#{common}/insights/practice_activities#{url_params}"},
          7 => {"Surveys", "#{common}/insights/surveys#{url_params}"},
          8 => {"Manage", "#{common}/manage#{url_params}"},
          9 => {"Activity", "#{common}/activity#{url_params}"}
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
