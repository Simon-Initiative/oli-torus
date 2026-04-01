defmodule Oli.InstructorDashboard.DataSnapshot.ProjectionsTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.Dashboard.Snapshot.Projections
  alias Oli.InstructorDashboard.DataSnapshot.Projections, as: InstructorProjections
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Resources.ResourceType

  describe "instructor capability projections" do
    # @ac "AC-008"
    test "uses capability projection modules with mixed ready and partial outcomes" do
      snapshot = snapshot_fixture()

      assert {:ok, %{projections: projections, statuses: statuses}} =
               Projections.derive_all(snapshot)

      assert Map.keys(InstructorProjections.modules()) |> Enum.sort() ==
               [
                 :summary,
                 :progress,
                 :student_support,
                 :challenging_objectives,
                 :assessments,
                 :ai_context
               ]
               |> Enum.sort()

      assert statuses.progress.status == :ready
      assert statuses.student_support.status == :ready
      assert statuses.assessments.status == :ready
      assert statuses.challenging_objectives.status == :ready

      assert statuses.summary.status == :partial
      assert statuses.summary.reason_code == :dependency_unavailable
      assert statuses.ai_context.status == :partial
      assert statuses.ai_context.reason_code == :dependency_unavailable

      assert projections.progress.progress_tile.axis_label == "Course Content"
      assert projections.progress.progress_tile.class_size == 10

      assert Enum.map(projections.progress.progress_tile.series_all, & &1.label) ==
               ["Module 7", "Quiz 1"]

      assert projections.student_support.support.default_bucket_id == "struggling"

      assert Enum.find(projections.student_support.support.buckets, &(&1.id == "struggling")).count ==
               1

      assert projections.challenging_objectives.state == :empty_low_proficiency
      assert projections.challenging_objectives.rows == []
      assert projections.assessments.assessments.has_assessments?
      assert projections.assessments.assessments.total_rows == 1
      assert Enum.at(projections.assessments.assessments.rows, 0).assessment_id == 42

      assert projections.summary.required_oracles.oracle_instructor_progress == %{
               metric: :progress
             }

      assert projections.ai_context.progress == %{metric: :progress}
    end

    test "derives affected capabilities from projection dependency metadata" do
      assert Enum.sort(InstructorProjections.affected_capabilities(:oracle_instructor_progress)) ==
               Enum.sort([
                 :summary,
                 :ai_context
               ])

      assert InstructorProjections.affected_capabilities(:oracle_instructor_progress_bins) ==
               [:progress]

      assert Enum.sort(InstructorProjections.affected_capabilities(:oracle_instructor_grades)) ==
               [:assessments]

      assert Enum.sort(
               InstructorProjections.affected_capabilities(:oracle_instructor_scope_resources)
             ) == Enum.sort([:progress, :assessments, :challenging_objectives])

      assert InstructorProjections.affected_capabilities(:oracle_instructor_progress_proficiency) ==
               [:student_support]

      assert InstructorProjections.affected_capabilities(
               :oracle_instructor_objectives_proficiency
             ) == [:challenging_objectives]

      assert InstructorProjections.affected_capabilities(:oracle_instructor_student_info) ==
               [:student_support]
    end
  end

  defp snapshot_fixture do
    section = insert(:section)
    project = insert(:project)
    unit_resource = insert(:resource)

    unit =
      insert(:section_resource, %{
        section: section,
        project: project,
        resource_id: unit_resource.id,
        resource_type_id: ResourceType.id_for_container(),
        title: "Unit 777",
        slug: "unit-777",
        numbering_index: 1,
        numbering_level: 1
      })

    SectionResourceDepot.update_section_resource(unit)

    {:ok, snapshot} =
      Contract.new_snapshot(%{
        request_token: "token-instructor-proj-1",
        context: %{
          dashboard_context_type: :section,
          dashboard_context_id: section.id,
          user_id: 88,
          scope: %{container_type: :container, container_id: unit.resource_id}
        },
        metadata: %{timezone: "UTC"},
        oracles: %{
          oracle_instructor_progress: %{metric: :progress},
          oracle_instructor_progress_bins: %{
            total_students: 10,
            by_resource_bins: %{
              777 => %{0 => 1, 100 => 9},
              42 => %{0 => 2, 100 => 8}
            }
          },
          oracle_instructor_grades: %{
            grades: [
              %{
                page_id: 42,
                title: "Quiz 1",
                minimum: 10.0,
                median: 70.0,
                mean: 72.5,
                maximum: 100.0,
                standard_deviation: 12.0,
                histogram: %{"70-80" => 1},
                completed_count: 1,
                total_students: 1
              }
            ]
          },
          oracle_instructor_scope_resources: %{
            course_title: "Intro to Testing",
            scope_label: "Unit 777",
            items: [
              %{
                resource_id: 777,
                resource_type_id: Oli.Resources.ResourceType.id_for_container(),
                title: "Module 7"
              },
              %{
                resource_id: 42,
                resource_type_id: Oli.Resources.ResourceType.id_for_page(),
                title: "Quiz 1",
                context_label: "Module 1"
              }
            ]
          },
          oracle_instructor_progress_proficiency: [
            %{student_id: 1, progress_pct: 25.0, proficiency_pct: 30.0}
          ],
          oracle_instructor_student_info: [
            %{
              student_id: 1,
              email: "ada@example.edu",
              given_name: "Ada",
              family_name: "Lovelace",
              last_interaction_at: ~U[2026-03-12 00:00:00Z]
            }
          ],
          oracle_instructor_section_analytics: %{metric: :assessment},
          oracle_instructor_objectives_proficiency: %{
            objective_rows: [
              %{
                objective_id: 7001,
                title: "Objective 7001",
                proficiency_distribution: %{"High" => 2}
              }
            ],
            objective_resources: []
          }
        },
        oracle_statuses: %{
          oracle_instructor_progress: %{status: :ready},
          oracle_instructor_grades: %{status: :ready},
          oracle_instructor_progress_bins: %{status: :ready},
          oracle_instructor_grades: %{status: :ready},
          oracle_instructor_scope_resources: %{status: :ready},
          oracle_instructor_progress_proficiency: %{status: :ready},
          oracle_instructor_student_info: %{status: :ready},
          oracle_instructor_section_analytics: %{status: :ready},
          oracle_instructor_objectives_proficiency: %{status: :ready}
        }
      })

    snapshot
  end
end
