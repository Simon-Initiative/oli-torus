defmodule OliWeb.Deliver.StudentOnboarding.WizardTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias Oli.Delivery.Sections
  alias Oli.Repo

  defp onboarding_wizard_route(section_slug) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.Delivery.StudentOnboarding.Wizard, section_slug)
  end

  defp section_overview_route(section_slug) do
    ~p"/sections/#{section_slug}"
  end

  describe "Student Onboarding Wizard - Redirection" do
    setup [:user_conn]

    test "when the user has accessed a section resource, it can see the section overview", %{
      conn: conn,
      user: student
    } do
      %{section: section, section_page: section_page} =
        basic_section(nil, %{title: "Chemistry 101"})

      enroll_student(student, section)
      stub_current_time(~U[2023-11-04 20:00:00Z])
      insert(:resource_access, user: student, section: section, resource: section_page.resource)

      conn = get(conn, section_overview_route(section.slug))

      assert html_response(conn, 200) =~ "Chemistry 101"
    end

    test "when the user has the \"visited\" flag in its enrollment, it can see the section overview",
         %{conn: conn, user: student} do
      %{section: section} = basic_section(nil, %{title: "Chemistry 101"})
      enroll_student(student, section, has_visited_section: true)
      stub_current_time(~U[2023-11-04 20:00:00Z])

      conn = get(conn, section_overview_route(section.slug))

      assert html_response(conn, 200) =~ "Chemistry 101"
    end

    test "when user doesn't have a resource access nor the enrollment \"visited\" flag, it gets redirected to the onboarding wizard",
         %{conn: conn, user: student} do
      %{section: section} = basic_section(nil, %{title: "Chemistry 101"})
      enroll_student(student, section)

      conn = get(conn, section_overview_route(section.slug))

      assert html_response(conn, 302) =~ onboarding_wizard_route(section.slug)
    end
  end

  describe "Student Onboarding Wizard - Introduction" do
    setup [:user_conn]

    test "the introduction step gets rendered", %{conn: conn, user: student} do
      %{section: section} = basic_section(nil, %{title: "Chemistry 201"})
      enroll_student(student, section)

      {:ok, view, _html} = live(conn, onboarding_wizard_route(section.slug))

      assert has_element?(view, "h2", "Welcome to Chemistry 201!")

      assert has_element?(
               view,
               "li",
               "A personalized Chemistry 201 experience based on your skillsets"
             )

      refute has_element?(
               view,
               "li",
               "A short survey to help shape your learning experience and let your instructor get to know yous"
             )

      refute has_element?(
               view,
               "li",
               "Explorations will bring the course to life, showing its relevance in the real world"
             )

      assert has_element?(view, "button", "Go to course")
      assert has_element?(view, "button", "Cancel")
    end

    test "the exploration description rendered when there are explorations", %{
      conn: conn,
      user: student
    } do
      section = insert(:section, %{contains_explorations: true})
      enroll_student(student, section)

      {:ok, view, _html} = live(conn, onboarding_wizard_route(section.slug))

      assert has_element?(
               view,
               "li",
               "Learning about the new ‘Exploration’ activities that provide real-world examples"
             )

      assert has_element?(view, "button", "Let's Begin")
    end

    test "the survey description rendered when the section has a survey", %{
      conn: conn,
      user: student
    } do
      {:ok, section: section, survey: _, survey_questions: _} = section_with_survey(nil)
      enroll_student(student, section)

      {:ok, view, _html} = live(conn, onboarding_wizard_route(section.slug))

      assert has_element?(
               view,
               "li",
               "A short survey to help shape your learning experience and let your instructor get to know you"
             )

      assert has_element?(view, "button", "Start Survey")
    end
  end

  describe "Student Onboarding Wizard - Survey" do
    setup [:user_conn, :section_with_survey]

    test "the survey gets rendered when the section has a survey", %{
      conn: conn,
      section: section,
      user: student
    } do
      enroll_student(student, section)

      {:ok, view, _html} = live(conn, onboarding_wizard_route(section.slug))

      view
      |> element("button", "Start Survey")
      |> render_click()

      view
      |> element("#eventIntercept")
      |> render_hook("survey_scripts_loaded", %{"loaded" => true})

      assert has_element?(view, "h2", "Course Survey")
      assert has_element?(view, "oli-multiple-choice-delivery")
      assert has_element?(view, "button", "Go to course")
    end
  end

  describe "Student Onboarding Wizard - Explorations" do
    setup [:user_conn]

    test "the survey gets rendered when the section has explorations", %{
      conn: conn,
      user: student
    } do
      section = insert(:section, %{contains_explorations: true})
      enroll_student(student, section)

      {:ok, view, _html} = live(conn, onboarding_wizard_route(section.slug))

      view
      |> element("button", "Let's Begin")
      |> render_click()

      assert has_element?(view, "h2", "Exploration Activities")

      assert has_element?(
               view,
               "span",
               "Explorations dig into how the course subject matter affects you"
             )

      assert has_element?(view, "button", "Go to course")
    end
  end

  defp enroll_student(student, section, opts \\ [has_visited_section: false]) do
    {:ok, enrollment} = enroll_user_to_section(student, section, :context_learner)

    if opts[:has_visited_section] do
      enrollment
      |> Sections.Enrollment.changeset(%{state: %{has_visited_once: true}})
      |> Repo.update()
    else
      enrollment
    end
  end
end
