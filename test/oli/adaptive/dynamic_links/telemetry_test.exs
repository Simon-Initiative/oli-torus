defmodule Oli.Adaptive.DynamicLinks.TelemetryTest do
  use ExUnit.Case, async: true

  alias Oli.Adaptive.DynamicLinks.Telemetry

  @created_event [:oli, :adaptive, :dynamic_link, :created]
  @updated_event [:oli, :adaptive, :dynamic_link, :updated]
  @removed_event [:oli, :adaptive, :dynamic_link, :removed]
  @resolved_event [:oli, :adaptive, :dynamic_link, :resolved]
  @resolution_failed_event [:oli, :adaptive, :dynamic_link, :resolution_failed]
  @broken_clicked_event [:oli, :adaptive, :dynamic_link, :broken_clicked]
  @delete_blocked_event [:oli, :adaptive, :dynamic_link, :delete_blocked]

  test "emits count-based telemetry with sanitized metadata" do
    handler = attach_telemetry([@created_event, @updated_event, @removed_event])

    Telemetry.authoring_created(2, %{
      project_id: 11,
      activity_resource_id: 22,
      user_email: "redact"
    })

    Telemetry.authoring_updated(1, %{project_slug: "demo", source: :activity_editor})
    Telemetry.authoring_removed(1, %{section_slug: "sec", reason: :removed})

    assert_receive {:telemetry_event, @created_event, %{count: 2}, created_metadata}
    assert created_metadata.project_id == 11
    assert created_metadata.activity_resource_id == 22
    refute Map.has_key?(created_metadata, :user_email)

    assert_receive {:telemetry_event, @updated_event, %{count: 1}, updated_metadata}
    assert updated_metadata.project_slug == "demo"
    assert updated_metadata.source == "activity_editor"

    assert_receive {:telemetry_event, @removed_event, %{count: 1}, removed_metadata}
    assert removed_metadata.section_slug == "sec"
    assert removed_metadata.reason == "removed"

    :telemetry.detach(handler)
  end

  test "emits delivery and deletion telemetry events" do
    handler =
      attach_telemetry([
        @resolved_event,
        @resolution_failed_event,
        @broken_clicked_event,
        @delete_blocked_event
      ])

    Telemetry.delivery_resolved(12, %{
      project_slug: "p",
      section_slug: "s",
      target_resource_id: 77
    })

    Telemetry.delivery_resolution_failed(%{project_slug: "p", reason: "resource_not_found"})
    Telemetry.delivery_broken_clicked(%{project_slug: "p", reason: "fallback_rendered"})
    Telemetry.delete_blocked(%{project_id: 44, target_resource_id: 77})

    assert_receive {:telemetry_event, @resolved_event, %{count: 1, duration_ms: 12},
                    resolved_metadata}

    assert resolved_metadata.project_slug == "p"
    assert resolved_metadata.section_slug == "s"
    assert resolved_metadata.target_resource_id == 77

    assert_receive {:telemetry_event, @resolution_failed_event, %{count: 1}, failed_metadata}
    assert failed_metadata.reason == "resource_not_found"

    assert_receive {:telemetry_event, @broken_clicked_event, %{count: 1}, broken_metadata}
    assert broken_metadata.reason == "fallback_rendered"

    assert_receive {:telemetry_event, @delete_blocked_event, %{count: 1}, blocked_metadata}
    assert blocked_metadata.project_id == 44
    assert blocked_metadata.target_resource_id == 77

    :telemetry.detach(handler)
  end

  defp attach_telemetry(events) do
    handler_id = "adaptive-dynamic-link-telemetry-test-#{System.unique_integer([:positive])}"
    parent = self()

    :ok =
      :telemetry.attach_many(
        handler_id,
        events,
        fn event_name, measurements, metadata, _config ->
          send(parent, {:telemetry_event, event_name, measurements, metadata})
        end,
        nil
      )

    handler_id
  end
end
