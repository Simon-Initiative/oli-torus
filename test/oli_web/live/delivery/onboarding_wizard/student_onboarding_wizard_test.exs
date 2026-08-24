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

    test "renders the default welcome message when the section description is empty", %{
      conn: conn,
      user: student
    } do
      %{section: section} =
        basic_section(nil, %{
          title: "Chemistry 201",
          description: nil,
          welcome_title: %{
            "type" => "p",
            "children" => [
              %{
                "id" => "unused-custom-title",
                "type" => "p",
                "children" => [%{"text" => "This custom title is not displayed"}]
              }
            ]
          },
          encouraging_subtitle: "This custom subtitle is not displayed"
        })

      enroll_student(student, section)

      {:ok, view, _html} = live(conn, onboarding_wizard_route(section.slug))

      assert has_element?(view, "#onboarding-welcome-title", "Welcome to Chemistry 201")
      refute render(view) =~ "This custom title is not displayed"
      refute has_element?(view, "#onboarding-welcome-subtitle")
      refute has_element?(view, "#onboarding-welcome-description")

      assert has_element?(
               view,
               "p",
               "Welcome to Chemistry 201! Here's what you can expect during this set up process."
             )

      assert has_element?(view, "button", "Go to course")
      assert has_element?(view, "button", "Cancel")
    end

    test "renders the section welcome fields when the description has content", %{
      conn: conn,
      user: student
    } do
      welcome_title = %{
        "type" => "p",
        "children" => [
          %{
            "id" => "custom-welcome-title",
            "type" => "p",
            "children" => [
              %{"text" => "Welcome to "},
              %{"text" => "Organic Chemistry", "strong" => true}
            ]
          }
        ]
      }

      section =
        insert(:section,
          title: "Chemistry 201",
          description: "Build a strong foundation for the experiments ahead.",
          welcome_title: welcome_title,
          encouraging_subtitle: "Discover how molecules shape our world."
        )

      enroll_student(student, section)

      {:ok, view, _html} = live(conn, onboarding_wizard_route(section.slug))

      assert has_element?(view, "#onboarding-welcome-title", "Welcome to Organic Chemistry")
      assert has_element?(view, "#onboarding-welcome-title strong", "Organic Chemistry")

      assert has_element?(
               view,
               "#onboarding-welcome-subtitle",
               "Discover how molecules shape our world."
             )

      assert has_element?(
               view,
               "#onboarding-welcome-description",
               "Build a strong foundation for the experiments ahead."
             )

      refute has_element?(view, "#onboarding-welcome-title", "Welcome to Chemistry 201")
    end

    test "renders the section cover image when present", %{conn: conn, user: student} do
      section =
        insert(:section, %{
          title: "Chemistry 201",
          cover_image: "https://example.com/onboarding-cover.png"
        })

      enroll_student(student, section)

      {:ok, view, _html} = live(conn, onboarding_wizard_route(section.slug))

      assert has_element?(
               view,
               ~s{img[src="https://example.com/onboarding-cover.png"]}
             )
    end

    test "falls back to the shared default course image when no cover image is present", %{
      conn: conn,
      user: student
    } do
      section = insert(:section, %{title: "Chemistry 201", cover_image: nil})
      enroll_student(student, section)

      {:ok, view, _html} = live(conn, onboarding_wizard_route(section.slug))

      assert has_element?(
               view,
               ~s{img[src="/images/course_default.png"]}
             )
    end

    test "the exploration description rendered when there are explorations", %{
      conn: conn,
      user: student
    } do
      section = insert(:section, %{contains_explorations: true, description: nil})
      enroll_student(student, section)

      {:ok, view, _html} = live(conn, onboarding_wizard_route(section.slug))

      assert has_element?(view, "button", "Let's Begin")
    end

    test "the survey description rendered when the section has a survey", %{
      conn: conn,
      user: student
    } do
      {:ok, section: section, survey: _, survey_questions: _} = section_with_survey(nil)
      enroll_student(student, section)

      {:ok, view, _html} = live(conn, onboarding_wizard_route(section.slug))

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
