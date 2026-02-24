defmodule Oli.InstructorDashboard.DataSnapshot.ProjectionsTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.Dashboard.Snapshot.Projections
  alias Oli.InstructorDashboard.DataSnapshot.Projections, as: InstructorProjections

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

      assert projections.progress.progress == %{metric: :progress}
      assert projections.student_support.support == %{metric: :support}
      assert projections.assessments.analytics == %{metric: :assessment}

      assert projections.summary.required_oracles.oracle_instructor_progress == %{
               metric: :progress
             }

      assert projections.ai_context.progress == %{metric: :progress}
    end
  end

  defp snapshot_fixture do
    {:ok, snapshot} =
      Contract.new_snapshot(%{
        request_token: "token-instructor-proj-1",
        context: %{
          dashboard_context_type: :section,
          dashboard_context_id: 101,
          user_id: 88,
          scope: %{container_type: :container, container_id: 777}
        },
        metadata: %{timezone: "UTC"},
        oracles: %{
          oracle_instructor_progress: %{metric: :progress},
          oracle_instructor_support: %{metric: :support},
          oracle_instructor_section_analytics: %{metric: :assessment}
        },
        oracle_statuses: %{
          oracle_instructor_progress: %{status: :ready},
          oracle_instructor_support: %{status: :ready},
          oracle_instructor_section_analytics: %{status: :ready}
        }
      })

    snapshot
  end
end
