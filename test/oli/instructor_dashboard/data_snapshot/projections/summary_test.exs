defmodule Oli.InstructorDashboard.DataSnapshot.Projections.SummaryTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Summary

  describe "required_oracles/0 and optional_oracles/0" do
    test "declares optional summary dependencies and no required oracles" do
      assert Summary.required_oracles() == []

      assert Summary.optional_oracles() == [
               :oracle_instructor_scope_resources,
               :oracle_instructor_progress_bins,
               :oracle_instructor_progress_proficiency,
               :oracle_instructor_grades,
               :oracle_instructor_objectives_proficiency,
               :oracle_instructor_recommendation
             ]
    end
  end

  describe "derive/2" do
    test "builds a partial summary projection with tile and export fields from available inputs" do
      assert {:partial, projection, {:dependency_unavailable, missing}} =
               Summary.derive(snapshot_fixture(), [])

      assert projection.capability == :summary
      assert projection.scope.selector == "container:777"
      assert projection.scope.label == "Unit 777"
      assert projection.scope.course_title == "Intro to Testing"
      assert projection.total_students == 12
      assert projection.metrics.average_student_progress == 60.0
      assert is_nil(projection.metrics.average_assessment_score)
      assert projection.metrics.average_class_proficiency == 60.0
      assert projection.missing_optional_oracles == missing

      assert projection.summary_tile.layout.visible_card_count == 2

      assert Enum.map(projection.summary_tile.cards, & &1.id) == [
               :average_class_proficiency,
               :average_student_progress
             ]

      assert Enum.sort(missing) == [
               :oracle_instructor_grades,
               :oracle_instructor_recommendation
             ]
    end

    test "returns ready when all optional summary inputs are present" do
      snapshot =
        snapshot_fixture(%{
          oracle_instructor_grades: %{
            grades: [
              %{page_id: 11, mean: 70.0, total_students: 12},
              %{page_id: 12, mean: 80.0, total_students: 10}
            ]
          },
          oracle_instructor_recommendation: %{
            status: :ready,
            recommendation_id: "rec-33",
            body: "Revisit Unit 777."
          }
        })

      assert {:ok, projection} = Summary.derive(snapshot, [])
      assert projection.metrics.average_assessment_score == 75.0
      assert projection.summary_tile.layout.visible_card_count == 3
      assert projection.summary_tile.recommendation.status == :ready
      assert projection.summary_tile.recommendation.recommendation_id == "rec-33"
      assert projection.summary_tile.scope_label == "Unit 777"
      assert projection.missing_optional_oracles == []
    end
  end

  defp snapshot_fixture(overrides \\ %{}) do
    default_oracles = %{
      oracle_instructor_scope_resources: %{
        course_title: "Intro to Testing",
        scope_label: "Unit 777",
        items: []
      },
      oracle_instructor_progress_bins: %{
        total_students: 12
      },
      oracle_instructor_progress_proficiency: [
        %{student_id: 1, progress_pct: 40.0, proficiency_pct: 0.8},
        %{student_id: 2, progress_pct: 80.0, proficiency_pct: 0.9}
      ],
      oracle_instructor_objectives_proficiency: %{
        objective_rows: [
          %{objective_id: 1001, title: "Objective 1", proficiency_distribution: %{"Low" => 2, "Medium" => 1}},
          %{objective_id: 1002, title: "Objective 2", proficiency_distribution: %{"High" => 2, "Medium" => 1}}
        ]
      }
    }

    oracles =
      overrides
      |> Enum.reduce(default_oracles, fn
        {key, nil}, acc -> Map.delete(acc, key)
        {key, value}, acc -> Map.put(acc, key, value)
      end)

    {:ok, snapshot} =
      Contract.new_snapshot(%{
        request_token: "token-summary-proj-1",
        context: %{
          dashboard_context_type: :section,
          dashboard_context_id: 101,
          user_id: 88,
          scope: %{container_type: :container, container_id: 777}
        },
        metadata: %{timezone: "UTC"},
        oracles: oracles,
        oracle_statuses:
          Enum.into(Map.keys(oracles), %{}, fn key ->
            {key, %{status: :ready}}
          end)
      })

    snapshot
  end
end
