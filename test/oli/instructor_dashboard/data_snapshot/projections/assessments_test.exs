defmodule Oli.InstructorDashboard.DataSnapshot.Projections.AssessmentsTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Assessments

  describe "required_oracles/0 and optional_oracles/0" do
    test "declare the grades and scope resources requirements" do
      assert Assessments.required_oracles() == [
               :oracle_instructor_grades,
               :oracle_instructor_scope_resources
             ]

      assert Assessments.optional_oracles() == []
    end
  end

  describe "derive/2" do
    test "builds the assessments projection from grades and scoped resources" do
      assert {:ok, projection} =
               Assessments.derive(snapshot_fixture(), completion_threshold_pct: 60)

      assert projection.capability == :assessments
      assert projection.optional_oracles == %{}
      assert projection.assessments.has_assessments? == true
      assert projection.assessments.total_rows == 2

      assert Enum.map(projection.assessments.rows, & &1.assessment_id) == [22, 11]

      [first, second] = projection.assessments.rows

      assert first.title == "Assessment Without Due Date"
      assert first.context_label == "Unit 1"
      assert first.completion.status == :bad
      assert first.metrics.mean == 55.0

      assert second.title == "Assessment With Due Date"
      assert second.context_label == "Unit 1 > Module 1"
      assert second.completion.completed_count == 8
      assert second.completion.total_students == 10
      assert second.completion.status == :good
      assert second.review_resource_id == 111
      assert Enum.find(second.histogram_bins, &(&1.range == "80-90")).count == 3
    end

    test "returns a deterministic error when a required oracle is missing" do
      snapshot = snapshot_fixture(%{oracle_instructor_scope_resources: nil})

      assert {:error, {:missing_required_oracles, [:oracle_instructor_scope_resources]}} =
               Assessments.derive(snapshot, [])
    end
  end

  defp snapshot_fixture(overrides \\ %{}) do
    default_oracles = %{
      oracle_instructor_grades: %{
        grades: [
          %{
            page_id: 11,
            section_resource_id: 111,
            title: "Assessment With Due Date",
            due_at: ~U[2026-04-15 12:00:00Z],
            available_at: ~U[2026-04-01 12:00:00Z],
            mean: 82.4,
            histogram: %{"80-90" => 3},
            completed_count: 8,
            total_students: 10
          },
          %{
            page_id: 22,
            title: "Assessment Without Due Date",
            available_at: ~U[2026-03-20 12:00:00Z],
            mean: 55.0,
            histogram: %{"50-60" => 2},
            completed_count: 4,
            total_students: 10
          }
        ]
      },
      oracle_instructor_scope_resources: %{
        items: [
          %{resource_id: 22, title: "Assessment Without Due Date", context_label: "Unit 1"},
          %{
            resource_id: 11,
            title: "Assessment With Due Date",
            context_label: "Unit 1 > Module 1"
          }
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
        request_token: "token-assessments-proj-1",
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
