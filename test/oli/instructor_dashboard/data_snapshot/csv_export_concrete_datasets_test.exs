defmodule Oli.InstructorDashboard.DataSnapshot.CsvExportConcreteDatasetsTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Scope
  alias Oli.InstructorDashboard.DataSnapshot.CsvExport

  alias Oli.InstructorDashboard.DataSnapshot.Projections.Assessments.Projector,
    as: AssessmentsProjector

  alias Oli.InstructorDashboard.DataSnapshot.Projections.Progress.Projector, as: ProgressProjector

  alias Oli.InstructorDashboard.DataSnapshot.Projections.StudentSupport.Projector,
    as: StudentSupportProjector

  alias Oli.Resources.ResourceType

  describe "build_zip/2 with concrete instructor datasets" do
    test "builds the expected CSV bundle for the instructor dashboard profile" do
      assert {:ok, zip_binary, manifest} =
               CsvExport.build_zip(snapshot_bundle_fixture(), export_request_fixture())

      assert manifest.export_profile == :instructor_dashboard

      entries = unzip_to_memory(zip_binary)

      assert Map.keys(entries) |> Enum.sort() == [
               ~c"assessment_scores_distribution.csv",
               ~c"assessment_summary.csv",
               ~c"challenging_learning_objectives.csv",
               ~c"course_summary_metrics.csv",
               ~c"dashboard_metadata.csv",
               ~c"student_progress.csv",
               ~c"student_support_list.csv",
               ~c"student_support_summary.csv"
             ]

      metadata_csv = to_string(Map.fetch!(entries, ~c"dashboard_metadata.csv"))
      assert metadata_csv =~ "course_name,Gardening Pretest (Demo)"
      assert metadata_csv =~ "course_section,Spring 2026 • Section 01"
      assert metadata_csv =~ "dashboard_scope,Entire Course"
      assert metadata_csv =~ "generated_at,2026-02-04 11:25:18 EST"
      assert metadata_csv =~ "completion_threshold,100%"
      assert metadata_csv =~ "total_students,2"
      refute metadata_csv =~ "time_zone,"

      summary_csv = to_string(Map.fetch!(entries, ~c"course_summary_metrics.csv"))
      assert summary_csv =~ "average_class_proficiency,40,percent"
      assert summary_csv =~ "average_assessment_score,82.4,percent"
      assert summary_csv =~ "average_student_progress,75,percent"

      progress_csv = to_string(Map.fetch!(entries, ~c"student_progress.csv"))
      assert progress_csv =~ "content_item,students_completed,completion_rate"
      assert progress_csv =~ "Unit 1,1,50.0"
      assert progress_csv =~ "Unit 2,2,100.0"

      support_summary_csv = to_string(Map.fetch!(entries, ~c"student_support_summary.csv"))
      assert support_summary_csv =~ "struggling,1,50.0"
      assert support_summary_csv =~ "excelling,1,50.0"
      refute support_summary_csv =~ "inactive"

      support_list_csv = to_string(Map.fetch!(entries, ~c"student_support_list.csv"))

      assert support_list_csv =~
               "student_id,student_name,progress_pct,proficiency_pct,support_category,inactive"

      assert support_list_csv =~ "1,Ada Lovelace,25,35,struggling,False"
      assert support_list_csv =~ "2,Grace Hopper,82,88,excelling,False"

      objectives_csv =
        to_string(Map.fetch!(entries, ~c"challenging_learning_objectives.csv"))

      assert objectives_csv =~ "label,objective,sub_objective,proficiency"
      assert objectives_csv =~ "LO 1,Explain photosynthesis,,Low"
      assert objectives_csv =~ "2.1,Understand plant anatomy,Analyze root systems,Low"

      distribution_csv =
        to_string(Map.fetch!(entries, ~c"assessment_scores_distribution.csv"))

      assert distribution_csv =~ "Module 13 Quiz,80-90,3"
      assert distribution_csv =~ "Module 13 Quiz,90-100,1"

      summary_assessment_csv = to_string(Map.fetch!(entries, ~c"assessment_summary.csv"))

      assert summary_assessment_csv =~
               "Module 13 Quiz,2026-02-02,2026-02-07,1,1,50,70,82.4,95,8.7"
    end
  end

  defp snapshot_bundle_fixture do
    {:ok, scope} = Scope.new(%{container_type: :course})

    progress_projection =
      ProgressProjector.build(
        scope,
        %{
          total_students: 2,
          by_container_bins: %{
            101 => %{100 => 1},
            202 => %{100 => 2}
          }
        },
        %{
          items: [
            %{
              resource_id: 101,
              resource_type_id: ResourceType.id_for_container(),
              title: "Unit 1"
            },
            %{
              resource_id: 202,
              resource_type_id: ResourceType.id_for_container(),
              title: "Unit 2"
            }
          ]
        }
      )

    support_projection =
      StudentSupportProjector.build(
        [
          %{student_id: 1, progress_pct: 25.0, proficiency_pct: 35.0},
          %{student_id: 2, progress_pct: 82.0, proficiency_pct: 88.0}
        ],
        [
          %{
            student_id: 1,
            email: "ada@example.edu",
            given_name: "Ada",
            family_name: "Lovelace",
            last_interaction_at: ~U[2026-02-01 12:00:00Z]
          },
          %{
            student_id: 2,
            email: "grace@example.edu",
            given_name: "Grace",
            family_name: "Hopper",
            last_interaction_at: ~U[2026-02-04 12:00:00Z]
          }
        ],
        now: ~U[2026-02-04 16:25:18Z]
      )

    assessments_projection =
      AssessmentsProjector.build(
        [
          %{
            page_id: 11,
            section_resource_id: 111,
            title: "Module 13 Quiz",
            available_at: ~U[2026-02-02 12:00:00Z],
            due_at: ~U[2026-02-07 12:00:00Z],
            minimum: 50.0,
            median: 70.0,
            mean: 82.4,
            maximum: 95.0,
            standard_deviation: 8.7,
            histogram: %{"80-90" => 3, "90-100" => 1},
            completed_count: 1,
            total_students: 2
          }
        ],
        scope_resource_items: [
          %{resource_id: 11, title: "Module 13 Quiz", context_label: "Unit 2 > Module 13"}
        ]
      )

    %{
      request_token: "csv-ticket-datasets-1",
      scope: %{container_type: :course},
      snapshot: %{
        snapshot_version: 1,
        projection_version: 1,
        oracles: %{
          oracle_instructor_progress_proficiency: [
            %{student_id: 1, progress_pct: 50.0, proficiency_pct: 0.35},
            %{student_id: 2, progress_pct: 100.0, proficiency_pct: 0.88}
          ],
          oracle_instructor_grades: %{
            grades: [%{page_id: 11, mean: 82.4}]
          },
          oracle_instructor_objectives_proficiency: %{
            objective_rows: [
              %{
                objective_id: 201,
                title: "Explain photosynthesis",
                proficiency_distribution: %{"Low" => 2, "Medium" => 1}
              },
              %{
                objective_id: 203,
                title: "Analyze root systems",
                proficiency_distribution: %{"Low" => 2, "High" => 1}
              }
            ]
          }
        }
      },
      projections: %{
        summary: %{
          scope: %{
            selector: "course",
            label: "Entire Course",
            course_title: "Gardening Pretest (Demo)"
          },
          total_students: 2,
          metrics: %{
            average_class_proficiency: 40.0,
            average_assessment_score: 82.4,
            average_student_progress: 75.0
          }
        },
        progress: %{progress_tile: progress_projection},
        student_support: %{support: support_projection},
        challenging_objectives: %{
          rows: [
            %{
              objective_id: 201,
              title: "Explain photosynthesis",
              row_type: :objective,
              numbering: "1",
              proficiency_label: "Low",
              proficiency_distribution: %{"Low" => 2, "Medium" => 1},
              children: []
            },
            %{
              objective_id: 202,
              title: "Understand plant anatomy",
              row_type: :objective,
              numbering: "2",
              proficiency_label: "High",
              proficiency_distribution: %{"High" => 2},
              children: [
                %{
                  objective_id: 203,
                  title: "Analyze root systems",
                  row_type: :subobjective,
                  parent_title: "Understand plant anatomy",
                  numbering: "2.1",
                  proficiency_label: "Low",
                  proficiency_distribution: %{"Low" => 2, "High" => 1},
                  children: []
                }
              ]
            }
          ]
        },
        assessments: %{assessments: assessments_projection}
      },
      projection_statuses: %{
        summary: %{status: :ready},
        progress: %{status: :ready},
        student_support: %{status: :ready},
        challenging_objectives: %{status: :ready},
        assessments: %{status: :ready}
      }
    }
  end

  defp export_request_fixture do
    %{
      export_profile: :instructor_dashboard,
      include_manifest: false,
      generated_at: ~U[2026-02-04 16:25:18Z],
      course_name: "Gardening Pretest (Demo)",
      course_section: "Spring 2026 • Section 01",
      dashboard_scope: "course",
      dashboard_scope_label: "Entire Course",
      timezone: "America/New_York",
      progress_completion_threshold: 100,
      proficiency_definition: "Learning objective proficiency based on first-attempt correctness"
    }
  end

  defp unzip_to_memory(zip_binary) do
    zip_filename =
      Path.join(
        System.tmp_dir!(),
        "data_snapshot_csv_export_concrete_#{System.unique_integer([:positive])}.zip"
      )

    File.write!(zip_filename, zip_binary)

    {:ok, entries} = :zip.unzip(String.to_charlist(zip_filename), [:memory])
    File.rm!(zip_filename)

    Map.new(entries)
  end
end
