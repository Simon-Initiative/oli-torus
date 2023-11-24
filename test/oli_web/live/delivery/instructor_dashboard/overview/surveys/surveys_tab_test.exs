defmodule OliWeb.Delivery.InstructorDashboard.Overview.SurveysTabTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Delivery.Sections

  @survey_attrs %{
    graded: true,
    resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
    content: %{
      model: [
        %{
          type: "survey"
        }
      ]
    }
  }

  defp surveys_path(section_slug) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      section_slug,
      :overview,
      :surveys
    )
  end

  defp enroll_instructor(%{section: section, instructor: instructor}) do
    enroll_user_to_section(instructor, section, :context_instructor)

    {:ok, []}
  end

  describe "Instructor dashboard overview - surveys tab" do
    setup [:instructor_conn, :section_with_surveys, :enroll_instructor]

    test "it lists all surveys", %{conn: conn, section: section, surveys: surveys} do
      {:ok, view, _html} = live(conn, surveys_path(section.slug))
      IO.inspect(surveys, label: "inspect_survey")
      assert(surveys != nil)
      # open_browser(view)
      # assert has_element?(view, "#instructor_dashboard_table")
    end

    test "it not show question details when a row is not selected", %{
      conn: conn,
      section: section,
      surveys: surveys
    } do
      {:ok, view, _html} = live(conn, surveys_path(section.slug))
    end

    test "it show a question details when a row is selected", %{
      conn: conn,
      section: section,
      surveys: surveys
    } do
      {:ok, view, _html} = live(conn, surveys_path(section.slug))

      # |> element("tr#314248")
      # |> render_click()

      open_browser(view)
    end

    # test "it should display correct question details when an assessment is selected", conn do
    #   conn = get(conn, "/")

    #   # create the assessment

    #   # create the survey
    #   survey = %{}

    #   # create the question details

    #   {:ok, html, lv} = live(conn, "/sdf")
    #   # obtain the assesment iD
    #   html = lv |> element("tr ##{}") |> render_click()

    #   assert_push_event(lv, "load", payload)

    # end
  end

  describe "Survey list none exist" do
    test "it lists all surveys", %{conn: conn, section: section, surveys: surveys} do
      {:ok, view, _html} = live(conn, surveys_path(section.slug))

      open_browser(view)
    end
  end
end
