defmodule Oli.InstructorDashboard.DataSnapshot.Projections.Summary.ProjectorTest do
  use ExUnit.Case, async: true

  alias Oli.InstructorDashboard.DataSnapshot.Projections.Summary.Projector

  for has_objectives <- [true, false],
      has_assessments <- [true, false],
      students <- [:none, :not_started, :started] do
    @has_objectives has_objectives
    @has_assessments has_assessments
    @students students

    test "scope: objectives=#{has_objectives}, assessments=#{has_assessments}, students=#{students}" do
      projection =
        Projector.build(scope_oracles(@has_objectives, @has_assessments, @students),
          recommendation_oracle_keys: [:oracle_instructor_recommendation]
        )

      expected_ids = expected_card_ids(@has_objectives, @has_assessments)
      assert Enum.map(projection.cards, & &1.id) == expected_ids
      assert projection.layout.visible_card_count == length(expected_ids)

      case @students do
        :started ->
          assert Enum.map(projection.cards, & &1.value_text) ==
                   Enum.map(expected_ids, fn
                     :average_class_proficiency -> "70%"
                     :average_assessment_score -> "80%"
                     :average_student_progress -> "25%"
                   end)

          assert projection.activity_state == :started
          assert projection.recommendation.body == "Review the first unit."
          assert projection.recommendation.status == :ready

        _ ->
          assert Enum.map(projection.cards, & &1.value_text) ==
                   Enum.map(expected_ids, fn
                     :average_student_progress -> "0%"
                     _ -> "--"
                   end)

          assert Enum.all?(
                   Enum.reject(projection.cards, &(&1.id == :average_student_progress)),
                   &(&1.status == :no_data and is_nil(&1.value_number))
                 )

          assert projection.activity_state == :not_started
          assert projection.recommendation.status == :beginning_course
      end
    end
  end

  test "keeps applicable cards without a numeric estimate after attempts have begun" do
    oracles =
      scope_oracles(true, true, :not_started)
      |> Map.put(:oracle_instructor_progress_proficiency, [
        %{student_id: 1, progress_pct: 0.0, proficiency_pct: nil, proficiency_attempt_count: 1}
      ])

    projection =
      Projector.build(oracles, recommendation_oracle_keys: [:oracle_instructor_recommendation])

    assert projection.activity_state == :started
    assert Enum.map(projection.cards, & &1.value_text) == ["--", "--", "0%"]

    assert Enum.all?(
             Enum.take(projection.cards, 2),
             &(&1.status == :no_data and is_nil(&1.value_number))
           )

    assert projection.recommendation.body == "There isn't enough student data."
  end

  test "progress alone prevents initial copy without proficiency or assessment results" do
    oracles =
      scope_oracles(true, true, :not_started)
      |> Map.put(:oracle_instructor_progress_proficiency, [
        %{student_id: 1, progress_pct: 5.0, proficiency_pct: nil, proficiency_attempt_count: 0}
      ])

    projection =
      Projector.build(oracles, recommendation_oracle_keys: [:oracle_instructor_recommendation])

    assert projection.activity_state == :started
    assert Enum.map(projection.cards, & &1.value_text) == ["--", "--", "5%"]
    assert projection.recommendation.body == "There isn't enough student data."
  end

  test "old snapshots without evidence counts do not manufacture initial zeros" do
    oracles =
      scope_oracles(true, true, :not_started)
      |> Map.put(:oracle_instructor_progress_proficiency, [
        %{student_id: 1, progress_pct: 0.0, proficiency_pct: nil}
      ])

    projection = Projector.build(oracles)
    assert projection.activity_state == :unknown
    assert Enum.map(projection.cards, & &1.value_text) == ["--", "--", "0%"]
  end

  for oracle <- [
        :oracle_instructor_progress_proficiency,
        :oracle_instructor_objectives_proficiency,
        :oracle_instructor_grades
      ],
      status <- [:loading, :failed] do
    @oracle oracle
    @status status

    test "#{oracle} #{status} does not mean structural absence or initial zero" do
      oracles = scope_oracles(true, true, :none) |> Map.delete(@oracle)

      projection =
        Projector.build(oracles,
          oracle_statuses: %{@oracle => %{status: @status}},
          recommendation_oracle_keys: [:oracle_instructor_recommendation]
        )

      assert length(projection.cards) == 3
      assert projection.activity_state == :unknown
      assert Enum.all?(projection.cards, &(&1.value_text == "--"))

      expected_status =
        case @status do
          :loading -> :loading
          :failed -> :unavailable
        end

      assert Enum.any?(projection.cards, &(&1.status == expected_status))
      assert projection.recommendation.body == "There isn't enough student data."
    end
  end

  test "genuine zero results remain distinct from missing evidence" do
    oracles =
      scope_oracles(true, true, :not_started)
      |> Map.put(:oracle_instructor_objectives_proficiency, %{
        objective_rows: [%{objective_id: 10, numeric_proficiency: 0.0}]
      })
      |> Map.put(:oracle_instructor_grades, %{grades: [%{page_id: 20, mean: 0.0}]})

    projection = Projector.build(oracles)
    assert projection.activity_state == :started
    assert Enum.all?(projection.cards, &(&1.value_text == "0%" and &1.status == :ready))
  end

  test "a calculated assessment zero does not manufacture a proficiency zero" do
    oracles =
      scope_oracles(true, true, :not_started)
      |> Map.put(:oracle_instructor_grades, %{grades: [%{page_id: 20, mean: 0.0}]})

    projection = Projector.build(oracles)
    assert projection.activity_state == :started
    assert Enum.map(projection.cards, & &1.value_text) == ["--", "0%", "0%"]

    [proficiency, score, _progress] = projection.cards
    assert proficiency.status == :no_data
    assert proficiency.value_number == nil
    assert score.status == :ready
    assert score.value_number == 0.0
  end

  describe "build/2" do
    test "derives all three cards when progress, objectives, and grades are available" do
      projection =
        Projector.build(%{
          oracle_instructor_progress_proficiency: [
            %{student_id: 1, progress_pct: 25.0},
            %{student_id: 2, progress_pct: 75.0}
          ],
          oracle_instructor_objectives_proficiency: %{
            objective_rows: [
              %{objective_id: 10, proficiency_distribution: %{"High" => 2, "Low" => 1}},
              %{objective_id: 11, proficiency_distribution: %{"Medium" => 2}}
            ]
          },
          oracle_instructor_grades: %{
            grades: [
              %{page_id: 101, mean: 80.0},
              %{page_id: 202, mean: 60.0}
            ]
          }
        })

      assert Enum.map(projection.cards, & &1.id) == [
               :average_class_proficiency,
               :average_assessment_score,
               :average_student_progress
             ]

      assert projection.layout.visible_card_count == 3
      assert projection.layout.card_grid_class == "grid-cols-3"

      assert Enum.find(projection.cards, &(&1.id == :average_student_progress)).value_text ==
               "50%"

      assert Enum.find(projection.cards, &(&1.id == :average_assessment_score)).value_text ==
               "70%"
    end

    test "weights class proficiency by the underlying learner counts across objectives" do
      projection =
        Projector.build(%{
          oracle_instructor_objectives_proficiency: %{
            objective_rows: [
              %{objective_id: 10, proficiency_distribution: %{"High" => 10}},
              %{objective_id: 11, proficiency_distribution: %{"Low" => 1}}
            ]
          }
        })

      assert Enum.find(projection.cards, &(&1.id == :average_class_proficiency)).value_text ==
               "84.5%"
    end

    test "prefers actual numeric objective proficiency over category reconstruction" do
      projection =
        Projector.build(%{
          oracle_instructor_objectives_proficiency: %{
            objective_rows: [
              %{
                objective_id: 10,
                numeric_proficiency: 0.42,
                proficiency_distribution: %{"High" => 10}
              },
              %{
                objective_id: 11,
                numeric_proficiency: 0.78,
                proficiency_distribution: %{"Low" => 10}
              }
            ]
          }
        })

      assert Enum.find(projection.cards, &(&1.id == :average_class_proficiency)).value_text ==
               "60%"
    end

    test "hides cards for missing objectives or assessments and expands remaining layout" do
      projection =
        Projector.build(%{
          oracle_instructor_progress_proficiency: [
            %{student_id: 1, progress_pct: 50.0}
          ],
          oracle_instructor_objectives_proficiency: %{objective_rows: []},
          oracle_instructor_grades: %{grades: []}
        })

      assert Enum.map(projection.cards, & &1.id) == [:average_student_progress]
      assert projection.layout.visible_card_count == 1
      assert projection.layout.card_grid_class == "grid-cols-1"

      assert Enum.sort(projection.missing_slots) == [
               :assessment,
               :proficiency_progress,
               :recommendation
             ]
    end

    test "emits beginning-course recommendation state from payload" do
      projection =
        Projector.build(
          %{
            oracle_instructor_recommendation: %{
              status: :beginning_course,
              recommendation_id: "rec-1",
              body: "Students haven't started yet."
            }
          },
          recommendation_oracle_keys: [:oracle_instructor_recommendation]
        )

      assert projection.recommendation.status == :beginning_course
      assert projection.recommendation.recommendation_id == "rec-1"
      assert projection.recommendation.body == "Students haven't started yet."
      assert projection.recommendation.can_regenerate? == true
    end

    test "uses thinking recommendation state when oracle status is still loading" do
      projection =
        Projector.build(
          %{},
          recommendation_oracle_keys: [:oracle_instructor_recommendation],
          oracle_statuses: %{
            oracle_instructor_recommendation: %{status: :loading}
          }
        )

      assert projection.recommendation.status == :thinking
      assert projection.recommendation.can_regenerate? == false
    end

    test "normalizes the merged MER-5305 payload shape for summary consumption" do
      projection =
        Projector.build(
          %{
            oracle_instructor_recommendation: %{
              id: 42,
              state: :no_signal,
              message:
                "There is no specific recommendation at this point in time, as there isn't enough student data.",
              feedback_summary: %{sentiment_submitted?: true}
            }
          },
          recommendation_oracle_keys: [:oracle_instructor_recommendation]
        )

      assert projection.recommendation.status == :beginning_course
      assert projection.recommendation.recommendation_id == "42"
      assert projection.recommendation.body =~ "there isn't enough student data"
      assert projection.recommendation.can_regenerate? == true
      assert projection.recommendation.can_submit_sentiment? == false
    end

    test "preserves explicit regen generation mode so remounts can keep regenerating copy" do
      projection =
        Projector.build(
          %{
            oracle_instructor_recommendation: %{
              id: 42,
              state: :generating,
              generation_mode: :explicit_regen,
              message: "Generating a fresh recommendation."
            }
          },
          recommendation_oracle_keys: [:oracle_instructor_recommendation],
          oracle_statuses: %{
            oracle_instructor_recommendation: %{status: :in_progress}
          }
        )

      assert projection.recommendation.status == :thinking
      assert projection.recommendation.generation_mode == :explicit_regen
      assert projection.recommendation.body == "Generating a fresh recommendation."
    end
  end

  defp expected_card_ids(has_objectives, has_assessments) do
    case has_objectives do
      true -> [:average_class_proficiency]
      false -> []
    end ++
      case has_assessments do
        true -> [:average_assessment_score]
        false -> []
      end ++
      [:average_student_progress]
  end

  defp scope_oracles(has_objectives, has_assessments, students) do
    progress_rows =
      case students do
        :none ->
          []

        :not_started ->
          [
            %{
              student_id: 1,
              progress_pct: 0.0,
              proficiency_pct: nil,
              proficiency_attempt_count: 0
            }
          ]

        :started ->
          [
            %{
              student_id: 1,
              progress_pct: 25.0,
              proficiency_pct: 0.7,
              proficiency_attempt_count: 3
            }
          ]
      end

    objective_rows =
      case has_objectives do
        false ->
          []

        true ->
          [
            %{
              objective_id: 10,
              numeric_proficiency:
                case students do
                  :started -> 0.7
                  _ -> nil
                end
            }
          ]
      end

    grades =
      case has_assessments do
        false ->
          []

        true ->
          [
            %{
              page_id: 20,
              mean:
                case students do
                  :started -> 80.0
                  _ -> nil
                end
            }
          ]
      end

    %{
      oracle_instructor_progress_proficiency: progress_rows,
      oracle_instructor_objectives_proficiency: %{objective_rows: objective_rows},
      oracle_instructor_grades: %{grades: grades},
      oracle_instructor_recommendation: %{
        id: 42,
        state:
          case students do
            :started -> :ready
            _ -> :no_signal
          end,
        message:
          case students do
            :started -> "Review the first unit."
            _ -> "There isn't enough student data."
          end
      }
    }
  end
end
