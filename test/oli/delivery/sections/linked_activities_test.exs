defmodule Oli.Delivery.Sections.LinkedActivitiesTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Sections.LinkedActivities

  test "resolves a parent objective family in stable order and handles cycles" do
    objectives = [
      %{resource_id: 10, children: [20, 30]},
      %{resource_id: 20, children: [30]},
      %{resource_id: 30, children: [10]}
    ]

    assert LinkedActivities.objective_family_ids(objectives, 10) == [10, 20, 30]
  end

  test "unions and de-duplicates direct activity relationships" do
    resources = [
      %{resource_id: 10, related_activities: [4, 2, 4]},
      %{resource_id: 20, related_activities: [3, 2]},
      %{resource_id: 30, related_activities: []}
    ]

    assert LinkedActivities.unique_activity_ids(resources) == [2, 3, 4]
  end

  test "a child objective excludes sibling and unrelated activities" do
    objectives = [%{resource_id: 10, children: [20, 30]}, %{resource_id: 20, children: []}]

    resources = [
      %{resource_id: 20, related_activities: [4]},
      %{resource_id: 30, related_activities: [5]},
      %{resource_id: 99, related_activities: [6]}
    ]

    family = LinkedActivities.objective_family_ids(objectives, 20)

    assert LinkedActivities.activity_ids_for_objective_family(family, resources) == [4]
  end

  test "empty relationships produce an empty activity list" do
    assert LinkedActivities.unique_activity_ids([%{resource_id: 1, related_activities: []}]) == []
  end

  test "a parent counts its descendants' activities and a leaf counts only its own" do
    objectives = [
      %{resource_id: 10, children: [20, 30], related_activities: [1]},
      %{resource_id: 20, children: [], related_activities: [2]},
      %{resource_id: 30, children: [], related_activities: [3, 4]}
    ]

    counts = LinkedActivities.activity_counts_by_family(objectives)

    assert counts[10] == 4
    assert counts[20] == 1
    assert counts[30] == 2
  end

  test "an activity declared by both a parent and its child is counted once" do
    objectives = [
      %{resource_id: 10, children: [20], related_activities: [1, 2]},
      %{resource_id: 20, children: [], related_activities: [2, 3]}
    ]

    assert LinkedActivities.activity_counts_by_family(objectives)[10] == 3
  end

  test "an activity shared by two sibling objectives is counted once" do
    objectives = [
      %{resource_id: 10, children: [20, 30], related_activities: []},
      %{resource_id: 20, children: [], related_activities: [7]},
      %{resource_id: 30, children: [], related_activities: [7]}
    ]

    assert LinkedActivities.activity_counts_by_family(objectives)[10] == 1
  end

  test "a cycle between objectives does not inflate the count" do
    objectives = [
      %{resource_id: 10, children: [20], related_activities: [1]},
      %{resource_id: 20, children: [10], related_activities: [2]}
    ]

    counts = LinkedActivities.activity_counts_by_family(objectives)

    assert counts[10] == 2
    assert counts[20] == 2
  end

  test "a child named outside the supplied objectives is skipped" do
    objectives = [%{resource_id: 10, children: [20, 999], related_activities: [1]}]

    assert LinkedActivities.activity_counts_by_family(objectives)[10] == 1
  end

  test "merges summary counts and recomputes ratios" do
    merged =
      LinkedActivities.merge_summary_metrics([
        %{num_attempts: 2, num_correct: 1, num_first_attempts: 2, num_first_attempts_correct: 1},
        %{num_attempts: 1, num_correct: 1, num_first_attempts: 1, num_first_attempts_correct: 1}
      ])

    assert merged.attempts == 3
    assert merged.correct == 2
    assert merged.avg_score == 2 / 3
    assert merged.first_attempt_pct == 2 / 3
  end

  test "zero denominators produce zero ratios" do
    merged = LinkedActivities.merge_summary_metrics([%{num_attempts: 0, num_first_attempts: 0}])

    assert merged.avg_score == 0.0
    assert merged.first_attempt_pct == 0.0
  end

  test "normalizes row fields and derives LTI state from activity type" do
    revision = %{
      resource_id: 7,
      activity_type_id: 42,
      title: "Question",
      slug: "tool",
      content: %{"stem" => %{"content" => [%{"text" => "Stem"}]}}
    }

    row =
      LinkedActivities.normalize_activity_row(
        revision,
        %{attempts: 4, percent_correct: 75.0},
        [%{page_resource_id: 100}],
        [42]
      )

    assert row.resource_id == 7
    assert row.total_attempts == 4
    assert row.avg_score == 0.75
    assert row.page_contexts == [%{page_resource_id: 100}]
    assert row.has_lti_activity
  end

  test "rows expose the title so sorting works when the stem cannot be extracted" do
    revision = %{
      resource_id: 7,
      activity_type_id: 1,
      title: "Multiple Choice:",
      slug: "mc",
      content: %{}
    }

    row =
      LinkedActivities.normalize_activity_row(
        revision,
        %{attempts: 0, percent_correct: 0.0},
        [],
        []
      )

    assert row.title == "Multiple Choice:"
    assert row.question_stem == "No question stem available"
  end

  test "telemetry metadata is allow-listed" do
    metadata =
      LinkedActivities.telemetry_metadata(:load, %{
        section_id: 1,
        objective_id: 2,
        activity_count: 3,
        email: "private@example.com",
        raw_response: "private"
      })

    refute Map.has_key?(metadata, :email)
    refute Map.has_key?(metadata, :raw_response)
    assert metadata.operation == :load
    assert metadata.activity_count == 3
  end
end
