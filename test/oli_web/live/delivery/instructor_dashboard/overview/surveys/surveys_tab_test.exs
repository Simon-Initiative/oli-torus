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

      for survey <- surveys do
        assert has_element?(view, "##{survey.id}", survey.title)
      end
    end

    test "it not show question details when a row is not selected", %{
      conn: conn,
      section: section,
      surveys: surveys
    } do
      {:ok, view, _html} = live(conn, surveys_path(section.slug))
      refute has_element?(view, "#activity_detail")
    end

    test "it show a question details when a row is selected", %{
      conn: conn,
      section: section,
      surveys: surveys
    } do
      {:ok, view, _html} = live(conn, surveys_path(section.slug))

      [survey | _] = surveys

      view
      |> element("##{survey.id}")
      |> render_click(%{id: Integer.to_string(survey.id)})

      open_browser(view)
    end
  end

  # describe "Survey list none exist" do
  #   test "it lists all surveys", %{conn: conn, section: section, surveys: surveys} do
  #     {:ok, view, _html} = live(conn, surveys_path(section.slug))

  #     open_browser(view)
  #   end
  # end
end
