defmodule OliWeb.Components.Delivery.LearningObjectives.ComponentTest do
  use OliWeb.ConnCase, async: true

  import LiveComponentTests
  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.LearningObjectives

  describe "LearningObjectives component" do
    test "renders only top-level objectives in instructor table and counts respect filters", %{
      conn: conn
    } do
      objectives = [
        %{
          resource_id: 1,
          title: "LO.02",
          objective: "LO.02",
          subobjective: nil,
          student_proficiency_obj: "Low",
          student_proficiency_subobj: nil,
          student_proficiency_obj_dist: %{},
          container_ids: [10],
          related_activities_count: 0
        },
        %{
          resource_id: 2,
          title: "Sub.LO.2a",
          objective: "LO.02",
          objective_resource_id: 1,
          subobjective: "Sub.LO.2a",
          student_proficiency_obj: "Low",
          student_proficiency_subobj: "Low",
          student_proficiency_obj_dist: %{},
          student_proficiency_subobj_dist: %{},
          container_ids: [10],
          related_activities_count: 0
        },
        %{
          resource_id: 3,
          title: "Sub.LO.2b",
          objective: "LO.02",
          objective_resource_id: 1,
          subobjective: "Sub.LO.2b",
          student_proficiency_obj: "Low",
          student_proficiency_subobj: "Medium",
          student_proficiency_obj_dist: %{},
          student_proficiency_subobj_dist: %{},
          container_ids: [10],
          related_activities_count: 0
        },
        %{
          resource_id: 4,
          title: "Sub.LO.2c",
          objective: "LO.02",
          objective_resource_id: 1,
          subobjective: "Sub.LO.2c",
          student_proficiency_obj: "Low",
          student_proficiency_subobj: "High",
          student_proficiency_obj_dist: %{},
          student_proficiency_subobj_dist: %{},
          container_ids: [10],
          related_activities_count: 0
        },
        %{
          resource_id: 5,
          title: "LO.99",
          objective: "LO.99",
          subobjective: nil,
          student_proficiency_obj: "Low",
          student_proficiency_subobj: nil,
          student_proficiency_obj_dist: %{},
          container_ids: [99],
          related_activities_count: 0
        },
        %{
          resource_id: 6,
          title: "Sub.LO.99a",
          objective: "LO.99",
          objective_resource_id: 5,
          subobjective: "Sub.LO.99a",
          student_proficiency_obj: "Low",
          student_proficiency_subobj: "Low",
          student_proficiency_obj_dist: %{},
          student_proficiency_subobj_dist: %{},
          container_ids: [99],
          related_activities_count: 0
        }
      ]

      params = %{
        "selected_card_value" => "low_proficiency_outcomes",
        "filter_by" => "10",
        "sort_by" => "objective_instructor_dashboard"
      }

      {:ok, view, _html} =
        live_component_isolated(conn, LearningObjectives, %{
          id: "learning-objectives-test",
          objectives_tab: %{objectives: objectives, navigator_items: []},
          params: params,
          section_slug: "test-section",
          section_id: 1,
          section_title: "Test Section",
          current_user: %{email: "instructor@example.edu"},
          patch_url_type: :instructor_dashboard,
          student_id: nil,
          view: :insights,
          v25_migration: :done
        })

      html = render(view)

      assert html =~ "LO.02"
      refute html =~ "Sub.LO.2a"
      refute html =~ "Sub.LO.2b"
      refute html =~ "Sub.LO.2c"

      assert card_text(html, "low_proficiency_outcomes") =~ "1"
      assert card_text(html, "low_proficiency_skills") =~ "1"
    end
  end

  defp card_text(html, value) do
    {:ok, document} = Floki.parse_document(html)
    [card] = Floki.find(document, ~s(div[phx-value-selected="#{value}"]))
    Floki.text(card)
  end
end
