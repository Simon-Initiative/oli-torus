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

    assert LinkedActivities.activity_ids_for_objective(objectives, resources, 20) == [4]
  end

  test "empty relationships and missing page revisions produce empty indexes" do
    assert LinkedActivities.unique_activity_ids([%{resource_id: 1, related_activities: []}]) == []

    assert LinkedActivities.build_page_contexts([%{resource_id: 100, revision_id: 9}], []) == %{}
  end

  test "indexes activity references by page and selects the first canonical context" do
    page_resources = [
      %{resource_id: 100, revision_id: 1},
      %{resource_id: 200, revision_id: 2}
    ]

    revisions = [
      %{id: 1, resource_id: 1000, activity_refs: [7, 8]},
      %{id: 2, resource_id: 2000, activity_refs: [7]}
    ]

    contexts = LinkedActivities.build_page_contexts(page_resources, revisions)

    assert Enum.map(contexts[7], & &1.page_resource_id) == [100, 200]
    assert contexts[8] |> List.first() |> Map.get(:page_resource_id) == 100
    assert LinkedActivities.canonical_page_contexts(contexts)[7].page_resource_id == 100
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
