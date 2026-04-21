defmodule Oli.InstructorDashboard.DataSnapshot.Projections.Summary.ProjectorTest do
  use ExUnit.Case, async: true

  alias Oli.InstructorDashboard.DataSnapshot.Projections.Summary.Projector

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

    test "hides cards for missing objectives or assessments and expands remaining layout" do
      projection =
        Projector.build(%{
          oracle_instructor_progress_proficiency: [
            %{student_id: 1, progress_pct: 50.0}
          ]
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
end
