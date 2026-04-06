defmodule Oli.InstructorDashboard.DataSnapshot.Projections.Assessments.ProjectorTest do
  use ExUnit.Case, async: true

  alias Oli.InstructorDashboard.DataSnapshot.Projections.Assessments.Projector

  describe "build/2" do
    test "sorts by due date ascending and builds completion and histogram data" do
      projection =
        Projector.build([
          %{
            page_id: 1,
            section_resource_id: 101,
            title: "Quiz 1",
            due_at: ~U[2026-03-10 12:00:00Z],
            available_at: ~U[2026-03-01 12:00:00Z],
            minimum: 25.0,
            median: 50.0,
            mean: 55.0,
            maximum: 100.0,
            standard_deviation: 12.4,
            histogram: %{"0-10" => 1, "50-60" => 3},
            completed_count: 12,
            total_students: 20
          },
          %{
            page_id: 2,
            section_resource_id: 202,
            title: "Quiz 2",
            due_at: ~U[2026-03-15 12:00:00Z],
            available_at: ~U[2026-03-05 12:00:00Z],
            histogram: %{},
            completed_count: 4,
            total_students: 20
          }
        ])

      assert projection.has_assessments? == true
      assert Enum.map(projection.rows, & &1.assessment_id) == [1, 2]

      [first | _] = projection.rows
      assert first.completion.label == "12 of 20 students completed"
      assert first.completion.status == :good
      assert first.review_resource_id == 101
      assert first.metrics.mean == 55.0
      assert Enum.find(first.histogram_bins, &(&1.range == "50-60")).count == 3
      assert Enum.find(first.histogram_bins, &(&1.range == "10-20")).count == 0

      [_, second] = projection.rows
      assert second.completion.label == "4 of 20 students completed"
      assert second.completion.status == :bad
      assert second.review_resource_id == 202
    end

    test "orders by effective date ascending using due date or available date" do
      projection =
        Projector.build([
          %{
            page_id: 1,
            title: "Quiz 1",
            due_at: ~U[2026-03-05 12:00:00Z],
            available_at: ~U[2026-03-10 12:00:00Z],
            histogram: %{},
            completed_count: 0,
            total_students: 20
          },
          %{
            page_id: 2,
            title: "Quiz 2",
            available_at: ~U[2026-03-05 12:00:00Z],
            histogram: %{},
            completed_count: 0,
            total_students: 20
          },
          %{
            page_id: 3,
            title: "Quiz 3",
            available_at: ~U[2026-03-01 12:00:00Z],
            histogram: %{},
            completed_count: 0,
            total_students: 20
          }
        ])

      assert Enum.map(projection.rows, & &1.assessment_id) == [3, 1, 2]
    end

    test "uses hierarchy order as tiebreaker for matching effective dates" do
      projection =
        Projector.build(
          [
            %{
              page_id: 1,
              title: "Quiz 1",
              due_at: ~U[2026-03-05 12:00:00Z],
              histogram: %{},
              completed_count: 0,
              total_students: 20
            },
            %{
              page_id: 2,
              title: "Quiz 2",
              available_at: ~U[2026-03-05 12:00:00Z],
              histogram: %{},
              completed_count: 0,
              total_students: 20
            }
          ],
          scope_resource_items: [
            %{resource_id: 2, title: "Quiz 2", context_label: "Unit 1"},
            %{resource_id: 1, title: "Quiz 1", context_label: "Unit 1"}
          ]
        )

      assert Enum.map(projection.rows, & &1.assessment_id) == [2, 1]
    end

    test "falls back to hierarchy order when due and available dates are missing" do
      projection =
        Projector.build(
          [
            %{
              page_id: 1,
              title: "Quiz 1",
              histogram: %{},
              completed_count: 0,
              total_students: 20
            },
            %{
              page_id: 2,
              title: "Quiz 2",
              histogram: %{},
              completed_count: 0,
              total_students: 20
            }
          ],
          scope_resource_items: [
            %{resource_id: 2, title: "Quiz 2", context_label: "Unit 1"},
            %{resource_id: 1, title: "Quiz 1", context_label: "Unit 1"}
          ]
        )

      assert Enum.map(projection.rows, & &1.assessment_id) == [2, 1]
    end

    test "falls back to generated title when no title metadata is present" do
      projection =
        Projector.build([
          %{
            page_id: 77,
            histogram: %{},
            completed_count: 0,
            total_students: 0
          }
        ])

      assert [%{title: "Assessment 77"}] = projection.rows
    end

    test "uses scope resource context labels for unit to module to page chains" do
      projection =
        Projector.build(
          [
            %{
              page_id: 10,
              title: "Quiz 10",
              histogram: %{},
              completed_count: 0,
              total_students: 0
            }
          ],
          scope_resource_items: [
            %{resource_id: 10, title: "Quiz 10", context_label: "Unit 1 > Module 2"}
          ]
        )

      assert [%{context_label: "Unit 1 > Module 2"}] = projection.rows
    end

    test "uses scope resource context labels for unit to module to section to page chains" do
      projection =
        Projector.build(
          [
            %{
              page_id: 11,
              title: "Quiz 11",
              histogram: %{},
              completed_count: 0,
              total_students: 0
            }
          ],
          scope_resource_items: [
            %{resource_id: 11, title: "Quiz 11", context_label: "Unit 1 > Module 2 > Section 3"}
          ]
        )

      assert [%{context_label: "Unit 1 > Module 2 > Section 3"}] = projection.rows
    end

    test "returns an empty projection when there are no grades rows" do
      projection = Projector.build([])

      assert projection == %{rows: [], total_rows: 0, has_assessments?: false}
    end
  end
end
