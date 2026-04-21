defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.SummaryTileTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import LiveComponentTests

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.SummaryTile

  describe "SummaryTile" do
    test "renders scoped metric cards and accessible tooltip wiring", %{conn: conn} do
      {:ok, component, _html} =
        live_component_isolated(conn, SummaryTile, %{
          id: "summary_tile",
          projection: ready_projection(),
          projection_status: %{status: :ready},
          tile_state: %{regenerate_in_flight?: false}
        })

      assert has_element?(
               component,
               "#summary-metric-card-average_class_proficiency p",
               "Average"
             )

      assert has_element?(
               component,
               "#summary-metric-card-average_class_proficiency p",
               "Class Proficiency"
             )

      assert has_element?(component, "p", "81%")
      assert has_element?(component, "#summary-metric-card-average_assessment_score p", "Average")

      assert has_element?(
               component,
               "#summary-metric-card-average_assessment_score p",
               "Assessment Score"
             )

      assert has_element?(component, "p", "76%")
      assert has_element?(component, "#summary-metric-card-average_student_progress p", "Average")

      assert has_element?(
               component,
               "#summary-metric-card-average_student_progress p",
               "Student Progress"
             )

      assert has_element?(component, "p", "72%")

      assert has_element?(
               component,
               "button[aria-describedby='summary-tooltip-average_class_proficiency']"
             )

      assert has_element?(component, "#summary-tooltip-average_class_proficiency[role='tooltip']")
      assert has_element?(component, "h4", "AI Recommendation")
      assert has_element?(component, "p", "Focus on Unit 2 before the next quiz.")
      assert has_element?(component, "#summary-recommendation-panel-summary_tile")
      assert has_element?(component, "button[aria-label='Thumbs up recommendation']")
      assert has_element?(component, "button[aria-label='Thumbs down recommendation']")
      assert has_element?(component, "button[aria-label='Regenerate recommendation']")

      html = render(component)

      assert elem(:binary.match(html, "summary-metric-card-average_class_proficiency"), 0) <
               elem(:binary.match(html, "summary-metric-card-average_assessment_score"), 0)

      assert elem(:binary.match(html, "summary-metric-card-average_assessment_score"), 0) <
               elem(:binary.match(html, "summary-metric-card-average_student_progress"), 0)
    end

    test "renders loading recommendation and empty metric fallback", %{conn: conn} do
      {:ok, component, _html} =
        live_component_isolated(conn, SummaryTile, %{
          id: "summary_tile",
          projection: %{
            cards: [],
            recommendation: %{label: "AI Recommendation", status: :thinking},
            layout: %{visible_card_count: 0, card_grid_class: "grid-cols-1"}
          },
          projection_status: %{status: :partial}
        })

      assert has_element?(
               component,
               "div",
               "Summary metrics will appear as scoped progress, proficiency, and assessment data become available."
             )

      assert has_element?(
               component,
               "p",
               "Generating a scoped recommendation for this selection."
             )

      assert has_element?(component, "#summary-recommendation-panel-summary_tile")
      assert has_element?(component, "span", "Thinking...")
      refute has_element?(component, "button[aria-label='Regenerate recommendation']")
    end

    test "shows thinking state while the recommendation is generating or regenerating", %{
      conn: conn
    } do
      {:ok, component, _html} =
        live_component_isolated(conn, SummaryTile, %{
          id: "summary_tile",
          projection: %{
            cards: [],
            recommendation: %{
              label: "AI Recommendation",
              status: :thinking,
              body: nil,
              recommendation_id: "rec-unit-2",
              can_regenerate?: true,
              can_submit_sentiment?: false
            },
            layout: %{visible_card_count: 0, card_grid_class: "grid-cols-1"}
          },
          projection_status: %{status: :partial},
          tile_state: %{
            regenerate_in_flight?: true,
            submitted_sentiment: nil,
            last_recommendation_id: "rec-unit-2"
          }
        })

      assert has_element?(component, "span", "Thinking...")
      assert has_element?(component, "[aria-hidden='true'].animate-spin")
      refute has_element?(component, "button[aria-label='Thumbs up recommendation']")
      refute has_element?(component, "button[aria-label='Thumbs down recommendation']")
      refute has_element?(component, "button[aria-label='Additional feedback']")
      refute has_element?(component, "span", "Additional feedback submitted")
      refute has_element?(component, "button[aria-label='Regenerate recommendation']")
    end

    test "disables sentiment buttons after submission for the active recommendation", %{
      conn: conn
    } do
      {:ok, component, _html} =
        live_component_isolated(conn, SummaryTile, %{
          id: "summary_tile",
          projection: ready_projection(%{feedback_summary: %{sentiment_submitted?: true}}),
          projection_status: %{status: :ready},
          tile_state: %{
            regenerate_in_flight?: false,
            submitted_sentiment: nil,
            last_recommendation_id: nil
          }
        })

      assert has_element?(
               component,
               "button[aria-label='Additional feedback']",
               "Additional feedback"
             )

      refute has_element?(component, "button[aria-label='Thumbs up recommendation']")
      refute has_element?(component, "button[aria-label='Thumbs down recommendation']")
      refute has_element?(component, "button[aria-label='Regenerate recommendation'][disabled]")
    end

    test "shows submitted additional feedback state after navigation when feedback is already persisted",
         %{conn: conn} do
      {:ok, component, _html} =
        live_component_isolated(conn, SummaryTile, %{
          id: "summary_tile",
          projection:
            ready_projection(%{
              feedback_summary: %{
                sentiment_submitted?: true,
                additional_feedback_submitted?: true
              }
            }),
          projection_status: %{status: :ready},
          tile_state: %{
            regenerate_in_flight?: false,
            submitted_sentiment: nil,
            last_recommendation_id: nil
          }
        })

      assert has_element?(component, "span", "Additional feedback submitted")
      refute has_element?(component, "button[aria-label='Additional feedback']")
      refute has_element?(component, "button[aria-label='Thumbs up recommendation']")
      refute has_element?(component, "button[aria-label='Thumbs down recommendation']")
    end

    test "renders additional feedback modal and submitted confirmation states", %{conn: conn} do
      {:ok, component, _html} =
        live_component_isolated(conn, SummaryTile, %{
          id: "summary_tile",
          projection: ready_projection(),
          projection_status: %{status: :ready},
          tile_state: %{
            regenerate_in_flight?: false,
            submitted_sentiment: :up,
            last_recommendation_id: "rec-unit-2",
            show_additional_feedback_modal?: true,
            additional_feedback_text: "Needs more specificity.",
            additional_feedback_submitting?: false,
            additional_feedback_submitted?: false
          }
        })

      assert has_element?(component, "h1", "Additional feedback")
      assert has_element?(component, "textarea[name='feedback_text']")
      assert has_element?(component, "button", "Submit")

      LiveComponentTests.Driver.run(component, fn socket ->
        updated_attrs =
          Map.put(socket.assigns.lc_attrs, :tile_state, %{
            regenerate_in_flight?: false,
            submitted_sentiment: :up,
            last_recommendation_id: "rec-unit-2",
            show_additional_feedback_modal?: true,
            additional_feedback_text: "",
            additional_feedback_submitting?: false,
            additional_feedback_submitted?: true
          })

        {:reply, :ok, Phoenix.Component.assign(socket, :lc_attrs, updated_attrs)}
      end)

      assert render(component) =~ "Feedback submitted"
      assert render(component) =~ "Thanks. Your feedback was shared with the team."
    end

    test "shows regenerating copy and disables regenerate while the request is in flight", %{
      conn: conn
    } do
      {:ok, component, _html} =
        live_component_isolated(conn, SummaryTile, %{
          id: "summary_tile",
          projection: ready_projection(),
          projection_status: %{status: :ready},
          tile_state: %{
            regenerate_in_flight?: true,
            submitted_sentiment: nil,
            last_recommendation_id: "rec-unit-2"
          }
        })

      assert has_element?(
               component,
               "p",
               "Focus on Unit 2 before the next quiz."
             )

      assert has_element?(component, "span", "Thinking...")
      refute has_element?(component, "button[aria-label='Regenerate recommendation']")
    end

    test "keeps previous recommendation text during regenerate when incoming status is thinking",
         %{
           conn: conn
         } do
      {:ok, component, _html} =
        live_component_isolated(conn, SummaryTile, %{
          id: "summary_tile",
          projection: %{
            cards: [],
            recommendation: %{
              label: "AI Recommendation",
              status: :thinking,
              recommendation_id: "rec-unit-2",
              body: "There is no specific recommendation at this point in time.",
              can_regenerate?: true,
              can_submit_sentiment?: false
            },
            layout: %{visible_card_count: 0, card_grid_class: "grid-cols-1"}
          },
          projection_status: %{status: :ready},
          tile_state: %{
            regenerate_in_flight?: true,
            submitted_sentiment: nil,
            last_recommendation_id: "rec-unit-2"
          }
        })

      assert has_element?(
               component,
               "p",
               "There is no specific recommendation at this point in time."
             )
    end

    test "does not treat generation mode alone as regenerating without an in-flight request", %{
      conn: conn
    } do
      {:ok, component, _html} =
        live_component_isolated(conn, SummaryTile, %{
          id: "summary_tile",
          projection: %{
            recommendation: %{
              recommendation_id: "rec-unit-2",
              label: "AI Recommendation",
              state: :generating,
              generation_mode: :explicit_regen,
              body: nil,
              can_regenerate?: true,
              can_submit_sentiment?: false
            }
          },
          projection_status: %{status: :ready},
          tile_state: %{
            regenerate_in_flight?: false,
            submitted_sentiment: nil,
            last_recommendation_id: "rec-unit-2"
          }
        })

      assert has_element?(
               component,
               "p",
               "Generating a scoped recommendation for this selection."
             )
    end

    test "rerenders scoped values when the projection changes", %{conn: conn} do
      {:ok, component, _html} =
        live_component_isolated(conn, SummaryTile, %{
          id: "summary_tile",
          projection: ready_projection(),
          projection_status: %{status: :ready}
        })

      assert render(component) =~ "Scoped overview for Unit 2."
      assert render(component) =~ "72%"

      LiveComponentTests.Driver.run(component, fn socket ->
        updated_attrs =
          socket.assigns.lc_attrs
          |> Map.put(:projection, %{
            cards: [
              %{
                id: :average_student_progress,
                label: "Average Student Progress",
                value_text: "54%",
                tooltip_key: :average_student_progress
              }
            ],
            recommendation: %{
              label: "AI Recommendation",
              status: :ready,
              recommendation_id: "rec-module-3",
              body: "Shift attention to Module 3.",
              aria_label: "AI Recommendation",
              can_regenerate?: true,
              can_submit_sentiment?: true
            },
            layout: %{visible_card_count: 1, card_grid_class: "grid-cols-1"},
            scope_label: "Module 3"
          })

        {:reply, :ok, Phoenix.Component.assign(socket, :lc_attrs, updated_attrs)}
      end)

      html = render(component)

      assert html =~ "Scoped overview for Module 3."
      assert html =~ "54%"
      assert html =~ "Shift attention to Module 3."
      refute html =~ "Scoped overview for Unit 2."
    end
  end

  defp ready_projection(recommendation_overrides \\ %{}) do
    %{
      cards: [
        %{
          id: :average_class_proficiency,
          label: "Average Class Proficiency",
          value_text: "81%",
          tooltip_key: :average_class_proficiency
        },
        %{
          id: :average_assessment_score,
          label: "Average Assessment Score",
          value_text: "76%",
          tooltip_key: :average_assessment_score
        },
        %{
          id: :average_student_progress,
          label: "Average Student Progress",
          value_text: "72%",
          tooltip_key: :average_student_progress
        }
      ],
      recommendation:
        Map.merge(
          %{
            label: "AI Recommendation",
            status: :ready,
            recommendation_id: "rec-unit-2",
            body: "Focus on Unit 2 before the next quiz.",
            aria_label: "AI Recommendation",
            can_regenerate?: true,
            can_submit_sentiment?: true
          },
          recommendation_overrides
        ),
      layout: %{visible_card_count: 3, card_grid_class: "grid-cols-3"},
      scope_label: "Unit 2",
      course_title: "Biology 101"
    }
  end
end
