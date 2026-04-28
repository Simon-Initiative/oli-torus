defmodule OliWeb.Live.Components.Sections.InstructorAiRecommendationsComponentTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import LiveComponentTests
  import Oli.Factory

  alias Oli.Delivery.Sections
  alias Oli.InstructorDashboard.Recommendations.Prompt
  alias OliWeb.Live.Components.Sections.InstructorAiRecommendationsComponent

  describe "InstructorAiRecommendationsComponent" do
    setup do
      project = insert(:project)

      section =
        insert(:section,
          base_project: project,
          type: :enrollable,
          instructor_recommendations_enabled: true,
          instructor_recommendation_prompt_template: nil
        )

      %{section: section}
    end

    test "renders enabled toggle and default prompt template when no template is persisted", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} =
        live_component_isolated(conn, InstructorAiRecommendationsComponent, %{
          id: "recommendations-test",
          section: section
        })

      assert has_element?(view, "#recommendations-test-toggle-recommendations_checkbox[checked]")
      assert has_element?(view, "h5", "Prompt Templates")
      assert has_element?(view, "button", "Save")
    end

    test "toggle persists instructor_recommendations_enabled", %{conn: conn, section: section} do
      {:ok, view, _html} =
        live_component_isolated(conn, InstructorAiRecommendationsComponent, %{
          id: "recommendations-test",
          section: section
        })

      view |> form("#recommendations-test-toggle-recommendations", %{}) |> render_change()

      refute has_element?(view, "#recommendations-test-toggle-recommendations_checkbox[checked]")

      updated = Sections.get_section_by(id: section.id)
      refute updated.instructor_recommendations_enabled
    end

    test "saving a blank prompt persists the default template", %{conn: conn, section: section} do
      {:ok, section} =
        Sections.update_section(section, %{instructor_recommendation_prompt_template: "  "})

      {:ok, view, _html} =
        live_component_isolated(conn, InstructorAiRecommendationsComponent, %{
          id: "recommendations-test",
          section: section
        })

      view |> element("button", "Save") |> render_click()

      updated = Sections.get_section_by(id: section.id)
      assert updated.instructor_recommendation_prompt_template == Prompt.default_template()

      assert_receive {_ref,
                      {:push_event,
                       "instructor_ai_recommendations_set_value:recommendations-test",
                       %{value: value}}}

      assert value == Prompt.default_template()
    end
  end
end
