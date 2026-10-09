defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.SummaryTileTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import LiveComponentTests

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.SummaryTile
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Summary.Projector

  @beginning_copy "Students haven’t started yet. This dashboard will surface progress, proficiency, and areas needing attention as soon as activity begins."

  describe "SummaryTile" do
    for has_objectives <- [true, false],
        has_assessments <- [true, false],
        has_activity <- [true, false] do
      @has_objectives has_objectives
      @has_assessments has_assessments
      @has_activity has_activity

      test "renders objectives=#{has_objectives}, assessments=#{has_assessments}, activity=#{has_activity}",
           %{conn: conn} do
        projection = scope_projection(@has_objectives, @has_assessments, @has_activity)

        {:ok, component, _html} =
          live_component_isolated(conn, SummaryTile, %{
            id: "summary_tile",
            projection: projection,
            projection_status: %{status: :ready}
          })

        assert has_element?(component, "#summary-metric-card-average_class_proficiency") ==
                 @has_objectives

        assert has_element?(component, "#summary-metric-card-average_assessment_score") ==
                 @has_assessments

        assert has_element?(component, "#summary-metric-card-average_student_progress")
        assert has_element?(component, "#summary-recommendation-panel-summary_tile")

        for {id, applicable?, calculated_value} <- [
              {:average_class_proficiency, @has_objectives, "70%"},
              {:average_assessment_score, @has_assessments, "80%"}
            ],
            applicable? do
          assert has_element?(
                   component,
                   "#summary-metric-card-#{id} p",
                   case @has_activity do
                     true -> calculated_value
                     false -> "--"
                   end
                 )
        end

        assert has_element?(
                 component,
                 "#summary-metric-card-average_student_progress p",
                 case @has_activity do
                   true -> "25%"
                   false -> "0%"
                 end
               )

        assert has_element?(
                 component,
                 "#summary-recommendation-panel-summary_tile p",
                 case @has_activity do
                   true -> "Review the first unit."
                   false -> @beginning_copy
                 end
               )

        html = render(component)
        assert html =~ "px-[23px] py-[22px]"
        refute html =~ "lg:col-span-3"
        refute html =~ "Summary metrics will appear"
      end
    end

    test "keeps incalculable proficiency and score visible alongside partial progress", %{
      conn: conn
    } do
      projection = scope_projection(true, true, true)

      cards =
        Enum.map(projection.cards, fn
          %{id: :average_student_progress} = card -> card
          card -> %{card | value_number: nil, value_text: "--", status: :no_data}
        end)

      projection = %{
        projection
        | cards: cards,
          recommendation: %{
            projection.recommendation
            | status: :beginning_course,
              body: "There isn't enough student data."
          }
      }

      {:ok, component, _html} =
        live_component_isolated(conn, SummaryTile, %{
          id: "summary_tile",
          projection: projection,
          projection_status: %{status: :ready}
        })

      assert has_element?(component, "#summary-metric-card-average_class_proficiency p", "--")
      assert has_element?(component, "#summary-metric-card-average_assessment_score p", "--")
      assert has_element?(component, "#summary-metric-card-average_student_progress p", "25%")

      assert has_element?(
               component,
               "#summary-recommendation-panel-summary_tile p",
               "There isn't enough student data."
             )

      refute render(component) =~ @beginning_copy
    end

    test "shared-LO attempts without a summary value keep the initial copy", %{conn: conn} do
      projection =
        scope_projection(true, true, false, %{
          oracle_instructor_progress_proficiency: [
            %{
              student_id: 1,
              progress_pct: 0.0,
              proficiency_pct: nil,
              proficiency_attempt_count: 1
            }
          ]
        })

      {:ok, component, _html} =
        live_component_isolated(conn, SummaryTile, %{
          id: "summary_tile",
          projection: projection,
          projection_status: %{status: :ready}
        })

      assert has_element?(
               component,
               "#summary-recommendation-panel-summary_tile p",
               @beginning_copy
             )

      assert has_element?(component, "#summary-metric-card-average_class_proficiency p", "--")
      assert has_element?(component, "#summary-metric-card-average_assessment_score p", "--")
      assert has_element?(component, "#summary-metric-card-average_student_progress p", "0%")
    end

    for {signal, overrides} <- [
          {:proficiency_zero,
           %{
             oracle_instructor_objectives_proficiency: %{
               objective_rows: [%{objective_id: 10, numeric_proficiency: 0.0}]
             }
           }},
          {:shared_lo_proficiency,
           %{
             oracle_instructor_objectives_proficiency: %{
               objective_rows: [%{objective_id: 10, numeric_proficiency: 0.7}]
             }
           }},
          {:assessment_zero, %{oracle_instructor_grades: %{grades: [%{page_id: 20, mean: 0.0}]}}},
          {:progress,
           %{oracle_instructor_progress_proficiency: [%{student_id: 1, progress_pct: 5.0}]}}
        ] do
      @signal_overrides overrides

      test "#{signal} keeps insufficient-data copy instead of the initial copy", %{conn: conn} do
        projection = scope_projection(true, true, false, @signal_overrides)

        {:ok, component, _html} =
          live_component_isolated(conn, SummaryTile, %{
            id: "summary_tile",
            projection: projection,
            projection_status: %{status: :ready}
          })

        assert has_element?(
                 component,
                 "#summary-recommendation-panel-summary_tile p",
                 "There isn't enough student data."
               )

        refute render(component) =~ @beginning_copy
      end
    end

    for oracle <- [
          :oracle_instructor_progress_proficiency,
          :oracle_instructor_objectives_proficiency,
          :oracle_instructor_grades
        ] do
      @loading_oracle oracle

      test "cached no-signal copy waits for #{oracle} before choosing initial copy", %{conn: conn} do
        projection =
          scope_projection(true, true, false, %{},
            oracle_statuses: %{@loading_oracle => %{status: :loading}}
          )

        {:ok, component, _html} =
          live_component_isolated(conn, SummaryTile, %{
            id: "summary_tile",
            projection: projection,
            projection_status: %{status: :partial}
          })

        assert has_element?(
                 component,
                 "#summary-recommendation-panel-summary_tile p",
                 "Generating a scoped recommendation for this selection."
               )

        refute render(component) =~ @beginning_copy
        refute render(component) =~ "There isn't enough student data."
        refute has_element?(component, "button[aria-label='Regenerate recommendation']")

        LiveComponentTests.Driver.run(component, fn socket ->
          updated_attrs =
            socket.assigns.lc_attrs
            |> Map.put(:projection, scope_projection(true, true, false))
            |> Map.put(:projection_status, %{status: :ready})

          {:reply, :ok, Phoenix.Component.assign(socket, :lc_attrs, updated_attrs)}
        end)

        assert has_element?(
                 component,
                 "#summary-recommendation-panel-summary_tile p",
                 @beginning_copy
               )

        refute render(component) =~ "Generating a scoped recommendation for this selection."
      end
    end

    test "one displayed signal resolves cached no-signal copy while other metrics load", %{
      conn: conn
    } do
      projection =
        scope_projection(
          true,
          true,
          false,
          %{oracle_instructor_progress_proficiency: [%{student_id: 1, progress_pct: 5.0}]},
          oracle_statuses: %{
            oracle_instructor_objectives_proficiency: %{status: :loading},
            oracle_instructor_grades: %{status: :loading}
          }
        )

      {:ok, component, _html} =
        live_component_isolated(conn, SummaryTile, %{
          id: "summary_tile",
          projection: projection,
          projection_status: %{status: :partial}
        })

      assert has_element?(
               component,
               "#summary-recommendation-panel-summary_tile p",
               "There isn't enough student data."
             )

      refute render(component) =~ @beginning_copy
      refute render(component) =~ "Generating a scoped recommendation for this selection."
    end

    for metric_status <- [:ready, :loading, :failed] do
      @metric_status metric_status

      test "a valid recommendation stays visible with #{metric_status} metrics", %{conn: conn} do
        projection =
          scope_projection(
            true,
            true,
            false,
            %{
              oracle_instructor_recommendation: %{
                id: 42,
                state: :ready,
                message: "Review the first unit."
              }
            },
            oracle_statuses:
              Map.new(
                [
                  :oracle_instructor_progress_proficiency,
                  :oracle_instructor_objectives_proficiency,
                  :oracle_instructor_grades
                ],
                &{&1, %{status: @metric_status}}
              )
          )

        {:ok, component, _html} =
          live_component_isolated(conn, SummaryTile, %{
            id: "summary_tile",
            projection: projection,
            projection_status: %{status: :partial}
          })

        assert has_element?(
                 component,
                 "#summary-recommendation-panel-summary_tile p",
                 "Review the first unit."
               )

        refute render(component) =~ @beginning_copy
        refute render(component) =~ "Generating a scoped recommendation for this selection."
      end
    end

    test "failed metrics do not confirm initial copy or keep cached no-signal copy loading", %{
      conn: conn
    } do
      projection =
        scope_projection(true, true, false, %{},
          oracle_statuses: %{oracle_instructor_grades: %{status: :failed}}
        )

      {:ok, component, _html} =
        live_component_isolated(conn, SummaryTile, %{
          id: "summary_tile",
          projection: projection,
          projection_status: %{status: :partial}
        })

      assert has_element?(
               component,
               "#summary-recommendation-panel-summary_tile p",
               "There isn't enough student data."
             )

      refute render(component) =~ @beginning_copy
      refute render(component) =~ "Generating a scoped recommendation for this selection."
    end

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

      for metric <-
            ~w(average_class_proficiency average_assessment_score average_student_progress) do
        assert has_element?(
                 component,
                 "#summary-tooltip-#{metric}[phx-hook='Popover'][data-tooltip-mode='tooltip'][data-tooltip-align='right'][data-tooltip-offset='8'][data-tooltip-position='bottom']"
               )
      end

      assert has_element?(
               component,
               "#summary-tooltip-average_class_proficiency-content[role='tooltip'][popover='manual'][hidden]"
             )

      assert has_element?(
               component,
               "#summary-tooltip-trigger-average_class_proficiency[aria-describedby='summary-tooltip-average_class_proficiency-content']"
             )

      assert has_element?(component, "h4", "AI Recommendation")
      assert has_element?(component, "p", "Focus on Unit 2 before the next quiz.")
      assert has_element?(component, "#summary-recommendation-panel-summary_tile")
      assert has_element?(component, "button[aria-label='Good recommendation']")
      assert has_element?(component, "button[aria-label='Bad recommendation']")
      html = render(component)
      refute html =~ "lg:max-w-[1076px]"

      assert has_element?(
               component,
               "#summary-recommendation-tooltip-up-summary_tile",
               "Good recommendation"
             )

      assert has_element?(
               component,
               "#summary-recommendation-tooltip-down-summary_tile",
               "Bad recommendation"
             )

      assert has_element?(
               component,
               "#summary-recommendation-tooltip-regenerate-summary_tile",
               "Regenerate recommendation"
             )

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
      assert has_element?(component, "span[role='status']", "Thinking...")
      refute has_element?(component, "button[aria-label='Regenerate recommendation']")
      refute render(component) =~ "lg:col-span-3"
    end

    test "hides recommendation panel when instructor recommendations are disabled", %{conn: conn} do
      {:ok, component, _html} =
        live_component_isolated(conn, SummaryTile, %{
          id: "summary_tile",
          projection: ready_projection(),
          projection_status: %{status: :ready},
          show_recommendation: false
        })

      refute has_element?(component, "#summary-recommendation-panel-summary_tile")
      refute has_element?(component, "h4", "AI Recommendation")
      assert has_element?(component, "p", "81%")
      assert has_element?(component, "p", "76%")
      assert has_element?(component, "p", "72%")
      assert render(component) =~ "lg:max-w-[1076px]"

      assert has_element?(
               component,
               "#summary-tooltip-average_class_proficiency[phx-hook='Popover'][data-tooltip-mode='tooltip']"
             )
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

      refute has_element?(component, "button[aria-label='Good recommendation']")
      refute has_element?(component, "button[aria-label='Bad recommendation']")
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
      refute has_element?(component, "button[aria-label='Good recommendation']")
      refute has_element?(component, "button[aria-label='Bad recommendation']")
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

      assert has_element?(component, "h1", "Provide Additional Feedback")
      assert has_element?(component, "textarea[name='feedback_text']")
      assert has_element?(component, "button", "Submit")
      assert has_element?(component, "p", "We use this feedback to improve our AI features.")

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

      assert render(component) =~ "Thank you for your feedback!"
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

  defp scope_projection(
         has_objectives,
         has_assessments,
         has_activity,
         oracle_overrides \\ %{},
         opts \\ []
       ) do
    {progress, proficiency, score, state, body} =
      case has_activity do
        true -> {25.0, 0.7, 80.0, :ready, "Review the first unit."}
        false -> {0.0, nil, nil, :no_signal, "There isn't enough student data."}
      end

    objectives =
      case has_objectives do
        true -> [%{objective_id: 10, numeric_proficiency: proficiency}]
        false -> []
      end

    grades =
      case has_assessments do
        true -> [%{page_id: 20, mean: score}]
        false -> []
      end

    oracles = %{
      oracle_instructor_progress_proficiency: [
        %{
          student_id: 1,
          progress_pct: progress,
          proficiency_pct: proficiency,
          proficiency_attempt_count: 0
        }
      ],
      oracle_instructor_objectives_proficiency: %{objective_rows: objectives},
      oracle_instructor_grades: %{grades: grades},
      oracle_instructor_recommendation: %{id: 42, state: state, message: body}
    }

    Projector.build(
      Map.merge(oracles, oracle_overrides),
      Keyword.merge([recommendation_oracle_keys: [:oracle_instructor_recommendation]], opts)
    )
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
