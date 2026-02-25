defmodule Oli.Dashboard.Snapshot.TelemetryTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Snapshot.Telemetry

  @export_stop_event [:oli, :dashboard, :snapshot, :export, :stop]

  describe "events/0" do
    test "includes export telemetry event" do
      events = Telemetry.events()
      assert @export_stop_event in events
    end
  end

  describe "metadata sanitization" do
    test "export metadata remains pii-safe and normalized" do
      sanitized =
        Telemetry.sanitize_export_metadata(%{
          outcome: :ok,
          scope_container_type: :container,
          export_profile: :instructor_dashboard,
          dataset_count: 3,
          included_count: 2,
          excluded_count: 1,
          reason_code: :required_projection_failed,
          user_id: 99,
          dashboard_context_id: 77
        })

      assert sanitized.outcome == :ok
      assert sanitized.scope_container_type == :container
      assert sanitized.export_profile == :instructor_dashboard
      assert sanitized.dataset_count == 3
      assert sanitized.included_count == 2
      assert sanitized.excluded_count == 1
      assert sanitized.reason_code == :required_projection_failed
      refute Map.has_key?(sanitized, :user_id)
      refute Map.has_key?(sanitized, :dashboard_context_id)
    end
  end

  describe "event emission" do
    test "emits export_stop with expected metadata keys" do
      handler = attach_telemetry([@export_stop_event])

      Telemetry.export_stop(
        %{duration_ms: 12},
        %{
          outcome: :error,
          scope_container_type: :course,
          export_profile: :default,
          reason_code: :required_projection_failed
        }
      )

      assert_receive {:telemetry_event, @export_stop_event, %{duration_ms: 12}, export_metadata}
      assert export_metadata.outcome == :error
      assert export_metadata.scope_container_type == :course
      assert export_metadata.export_profile == :default
      assert export_metadata.reason_code == :required_projection_failed

      :telemetry.detach(handler)
    end
  end

  defp attach_telemetry(events) do
    handler_id = "snapshot-telemetry-test-#{System.unique_integer([:positive])}"
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
