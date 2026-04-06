defmodule Oli.GenAI.AdaptiveContextTelemetryTest do
  use ExUnit.Case, async: true

  alias Oli.GenAI.AdaptiveContextTelemetry

  @tool_exposed_event [:oli, :genai, :adaptive_context, :tool_exposed]
  @tool_called_event [:oli, :genai, :adaptive_context, :tool_called]
  @build_succeeded_event [:oli, :genai, :adaptive_context, :build_succeeded]
  @build_failed_event [:oli, :genai, :adaptive_context, :build_failed]

  test "emits tool exposure and tool call telemetry with sanitized metadata" do
    handler = attach_telemetry([@tool_exposed_event, @tool_called_event])

    AdaptiveContextTelemetry.tool_exposed(%{
      section_id: 77,
      student_response: "should not appear"
    })

    AdaptiveContextTelemetry.tool_called(%{
      section_id: "88",
      user_prompt: "do not keep"
    })

    assert_receive {:telemetry_event, @tool_exposed_event, %{count: 1}, exposed_metadata}
    assert exposed_metadata.section_id == 77
    refute Map.has_key?(exposed_metadata, :student_response)

    assert_receive {:telemetry_event, @tool_called_event, %{count: 1}, called_metadata}
    assert called_metadata.section_id == 88
    refute Map.has_key?(called_metadata, :user_prompt)

    :telemetry.detach(handler)
  end

  test "emits build success and failure telemetry without raw content" do
    handler = attach_telemetry([@build_succeeded_event, @build_failed_event])

    AdaptiveContextTelemetry.build_succeeded(14, %{
      section_id: 9,
      resource_attempt_id: 10,
      page_revision_id: 11,
      visited_screen_count: 2,
      unvisited_screen_count: 1,
      raw_answer: "redact"
    })

    AdaptiveContextTelemetry.build_failed(3, %{
      section_id: 9,
      resource_attempt_id: 10,
      page_revision_id: 11,
      reason: :no_access,
      screen_content: "redact"
    })

    assert_receive {:telemetry_event, @build_succeeded_event, success_measurements,
                    success_metadata}

    assert success_measurements == %{
             count: 1,
             duration_ms: 14,
             visited_screen_count: 2,
             unvisited_screen_count: 1
           }

    assert success_metadata.section_id == 9
    assert success_metadata.resource_attempt_id == 10
    assert success_metadata.page_revision_id == 11
    assert success_metadata.reason == nil
    refute Map.has_key?(success_metadata, :raw_answer)

    assert_receive {:telemetry_event, @build_failed_event, %{count: 1, duration_ms: 3},
                    failed_metadata}

    assert failed_metadata.section_id == 9
    assert failed_metadata.resource_attempt_id == 10
    assert failed_metadata.page_revision_id == 11
    assert failed_metadata.reason == :no_access
    refute Map.has_key?(failed_metadata, :screen_content)

    :telemetry.detach(handler)
  end

  defp attach_telemetry(events) do
    handler_id = "adaptive-context-telemetry-test-#{System.unique_integer([:positive])}"
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
