defmodule Oli.InstructorDashboard.Recommendations.BuilderTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.InstructorDashboard.Recommendations.Builder
  alias Oli.Resources.ResourceType

  describe "build_input_contract/2" do
    test "builds a sanitized recommendation input contract from normalized projections" do
      assert {:ok, contract} = Builder.build_input_contract(snapshot_fixture())

      assert contract.prompt_version == "recommendation_prompt_v1"
      assert contract.section_id == 101
      assert contract.scope.scope_label == "Unit 777"
      assert contract.signal_summary.state == :ready
      assert length(contract.datasets) == 4

      assert Enum.map(contract.datasets, & &1.key) == [
               :scope_overview,
               :progress_coverage,
               :student_support,
               :assessments
             ]

      snapshot_text = inspect(contract.prompt_snapshot)
      refute snapshot_text =~ "Ada"
      refute snapshot_text =~ "Lovelace"
      refute snapshot_text =~ "ada@example.edu"
    end

    test "classifies the contract as no-signal when there are no student or assessment signals" do
      assert {:ok, contract} =
               Builder.build_input_contract(no_signal_snapshot_fixture())

      assert contract.signal_summary.state == :no_signal
      assert :no_students in contract.signal_summary.reasons
      assert :no_activity_data in contract.signal_summary.reasons
      assert :no_assessment_signal in contract.signal_summary.reasons
    end
  end

  defp snapshot_fixture do
    {:ok, snapshot} =
      Contract.new_snapshot(%{
        request_token: "token-recommendation-builder-1",
        context: %{
          dashboard_context_type: :section,
          dashboard_context_id: 101,
          user_id: 88,
          scope: %{container_type: :container, container_id: 777}
        },
        metadata: %{timezone: "UTC"},
        oracles: %{
          oracle_instructor_progress_bins: %{
            total_students: 10,
            by_resource_bins: %{
              777 => %{0 => 1, 100 => 9},
              42 => %{0 => 2, 100 => 8}
            }
          },
          oracle_instructor_scope_resources: %{
            course_title: "Intro to Testing",
            scope_label: "Unit 777",
            items: [
              %{
                resource_id: 777,
                resource_type_id: ResourceType.id_for_container(),
                title: "Module 7"
              },
              %{
                resource_id: 42,
                resource_type_id: ResourceType.id_for_page(),
                title: "Quiz 1",
                context_label: "Module 1"
              }
            ]
          },
          oracle_instructor_progress_proficiency: [
            %{student_id: 1, progress_pct: 25.0, proficiency_pct: 30.0},
            %{student_id: 2, progress_pct: 88.0, proficiency_pct: 91.0}
          ],
          oracle_instructor_student_info: [
            %{
              student_id: 1,
              email: "ada@example.edu",
              given_name: "Ada",
              family_name: "Lovelace",
              last_interaction_at: ~U[2026-03-12 00:00:00Z]
            },
            %{
              student_id: 2,
              email: "grace@example.edu",
              given_name: "Grace",
              family_name: "Hopper",
              last_interaction_at: ~U[2026-03-15 00:00:00Z]
            }
          ],
          oracle_instructor_grades: %{
            grades: [
              %{
                page_id: 42,
                title: "Quiz 1",
                mean: 72.5,
                histogram: %{"70-80" => 1},
                completed_count: 8,
                total_students: 10
              }
            ]
          }
        },
        oracle_statuses: %{
          oracle_instructor_progress_bins: %{status: :ready},
          oracle_instructor_scope_resources: %{status: :ready},
          oracle_instructor_progress_proficiency: %{status: :ready},
          oracle_instructor_student_info: %{status: :ready},
          oracle_instructor_grades: %{status: :ready}
        }
      })

    snapshot
  end

  defp no_signal_snapshot_fixture do
    {:ok, snapshot} =
      Contract.new_snapshot(%{
        request_token: "token-recommendation-builder-2",
        context: %{
          dashboard_context_type: :section,
          dashboard_context_id: 101,
          user_id: 88,
          scope: %{container_type: :course, container_id: nil}
        },
        metadata: %{timezone: "UTC"},
        oracles: %{
          oracle_instructor_progress_bins: %{
            total_students: 0,
            by_resource_bins: %{}
          },
          oracle_instructor_scope_resources: %{
            course_title: "Intro to Testing",
            scope_label: "Entire Course",
            items: []
          },
          oracle_instructor_progress_proficiency: [],
          oracle_instructor_student_info: [],
          oracle_instructor_grades: %{grades: []}
        },
        oracle_statuses: %{
          oracle_instructor_progress_bins: %{status: :ready},
          oracle_instructor_scope_resources: %{status: :ready},
          oracle_instructor_progress_proficiency: %{status: :ready},
          oracle_instructor_student_info: %{status: :ready},
          oracle_instructor_grades: %{status: :ready}
        }
      })

    snapshot
  end
end
