defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.ChallengingObjectivesTileTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.ChallengingObjectivesTile

  describe "tile/1" do
    test "renders populated hierarchy with scoped links" do
      html =
        render_component(&ChallengingObjectivesTile.tile/1, %{
          projection: populated_projection(),
          projection_status: %{status: :ready},
          projection_identity: "token-1",
          section_slug: "bio-101"
        })

      assert html =~ "Challenging Objectives"

      assert html =~ "Your class is demonstrating"
      assert html =~ "low proficiency (&le; 40%)"
      assert html =~ "for these learning objectives."

      assert html =~ "View Learning Objectives"
      assert html =~ "LO 1"
      assert html =~ "Objective A"
      assert html =~ "1 Sub-objective"
      assert html =~ "1.1"
      assert html =~ "Sub Objective A.1"
      assert html =~ "Low"
      assert html =~ "filter_by=100"
      assert html =~ "navigation_source=challenging_objectives_tile"
      refute html =~ "selected_card_value="
      assert html =~ "subobjective_id=12"
      assert html =~ "Navigates to Learning Objectives."
      assert html =~ ~s(id="learning-dashboard-challenging-objectives-token-1")
      assert html =~ "<details"
    end

    test "renders no-data message distinctly from low-proficiency empty state" do
      no_data_html =
        render_component(&ChallengingObjectivesTile.tile/1, %{
          projection: %{
            state: :no_data,
            scope: %{label: "Entire Course"},
            navigation: %{view_all: %{}}
          },
          projection_status: %{status: :ready},
          projection_identity: "token-2",
          section_slug: "bio-101"
        })

      empty_html =
        render_component(&ChallengingObjectivesTile.tile/1, %{
          projection: %{
            state: :empty_low_proficiency,
            scope: %{label: "Entire Course"},
            navigation: %{view_all: %{}}
          },
          projection_status: %{status: :ready},
          projection_identity: "token-3",
          section_slug: "bio-101"
        })

      assert no_data_html =~ "No objective data yet."

      assert no_data_html =~
               "There is not enough proficiency data yet to highlight challenging objectives in Entire Course."

      assert empty_html =~ "No low-proficiency objectives."

      assert empty_html =~
               "There are currently no learning objectives with low proficiency in Entire Course."

      assert no_data_html =~
               ~s(/sections/bio-101/instructor_dashboard/insights/learning_objectives)

      assert empty_html =~ ~s(/sections/bio-101/instructor_dashboard/insights/learning_objectives)
      refute no_data_html =~ "No low-proficiency objectives."
      refute no_data_html =~ "Your class is demonstrating"
      refute empty_html =~ "Your class is demonstrating"
    end

    test "renders unavailable state when projection status is unavailable" do
      html =
        render_component(&ChallengingObjectivesTile.tile/1, %{
          projection: nil,
          projection_status: %{status: :unavailable},
          projection_identity: "token-4",
          section_slug: "bio-101"
        })

      assert html =~ "Objective insights are unavailable."
    end
  end

  defp populated_projection do
    %{
      state: :populated,
      row_count: 2,
      scope: %{label: "Unit 1"},
      navigation: %{
        view_all: %{filter_by: "100", navigation_source: "challenging_objectives_tile"}
      },
      rows: [
        %{
          objective_id: 11,
          numbering: "1",
          numbering_index: 10,
          title: "Objective A",
          row_type: :objective,
          proficiency_label: "Low",
          has_children: true,
          navigation: %{
            filter_by: "100",
            navigation_source: "challenging_objectives_tile",
            objective_id: 11
          },
          children: [
            %{
              objective_id: 12,
              numbering: "1.1",
              numbering_index: 11,
              title: "Sub Objective A.1",
              row_type: :subobjective,
              proficiency_label: "Low",
              parent_title: "Objective A",
              has_children: false,
              navigation: %{
                filter_by: "100",
                navigation_source: "challenging_objectives_tile",
                objective_id: 11,
                subobjective_id: 12
              },
              children: []
            }
          ]
        }
      ]
    }
  end
end
