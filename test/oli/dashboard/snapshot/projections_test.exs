defmodule Oli.Dashboard.Snapshot.ProjectionsTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.Dashboard.Snapshot.Projections
  alias Oli.Dashboard.SnapshotProjections.FailingProjection
  alias Oli.Dashboard.SnapshotProjections.PartialProjection
  alias Oli.Dashboard.SnapshotProjections.ReadyProjection

  @projection_stop_event [:oli, :dashboard, :snapshot, :projection, :stop]
  @projection_status_event [:oli, :dashboard, :snapshot, :projection, :status]

  describe "derive_all/2" do
    # @ac "AC-001"
    test "derives per-capability statuses without global readiness blocking" do
      snapshot = snapshot_fixture()

      handler = attach_telemetry([@projection_stop_event, @projection_status_event])

      assert {:ok, %{projections: projections, statuses: statuses}} =
               Projections.derive_all(snapshot,
                 projection_modules: %{
                   summary: ReadyProjection,
                   progress: PartialProjection,
                   student_support: FailingProjection
                 }
               )

      assert projections.summary.kind == :ready_projection
      assert projections.progress.kind == :partial_projection
      refute Map.has_key?(projections, :student_support)

      assert statuses.summary.status == :ready
      assert statuses.progress.status == :partial
      assert statuses.progress.reason_code == :dependency_unavailable
      assert statuses.student_support.status == :failed
      assert statuses.student_support.reason_code == :missing_oracle_payload

      assert_receive {:telemetry_event, @projection_stop_event, _measurements, metadata}
      assert metadata.capability_key in [:summary, :progress, :student_support]
      assert metadata.status in [:ready, :partial, :failed]
      assert_receive {:telemetry_event, @projection_status_event, %{count: 1}, _metadata}

      :telemetry.detach(handler)
    end
  end

  describe "derive/3" do
    test "returns deterministic unknown capability error" do
      assert {:error, {:projection_failed, {:unknown_capability, :missing_capability}}} =
               Projections.derive(:missing_capability, snapshot_fixture())
    end
  end

  defp snapshot_fixture do
    {:ok, snapshot} =
      Contract.new_snapshot(%{
        request_token: "token-proj-1",
        context: %{
          dashboard_context_type: :section,
          dashboard_context_id: 44,
          user_id: 200,
          scope: %{container_type: :course, container_id: nil}
        },
        metadata: %{timezone: "UTC"},
        oracles: %{oracle_instructor_progress: %{status: :placeholder}},
        oracle_statuses: %{oracle_instructor_progress: %{status: :ready}},
        projection_statuses: %{}
      })

    snapshot
  end

  defp attach_telemetry(events) do
    handler_id = "snapshot-projections-test-#{System.unique_integer([:positive])}"
    parent = self()

    :telemetry.attach_many(
      handler_id,
      events,
      fn event_name, measurements, metadata, _config ->
        send(parent, {:telemetry_event, event_name, measurements, metadata})
      end,
      %{}
    )

    handler_id
  end
end
