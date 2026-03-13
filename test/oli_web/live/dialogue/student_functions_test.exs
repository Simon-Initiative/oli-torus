defmodule OliWeb.Dialogue.StudentFunctionsTest do
  use ExUnit.Case, async: true

  alias OliWeb.Dialogue.StudentFunctions

  @tool_exposed_event [:oli, :genai, :adaptive_context, :tool_exposed]
  @tool_called_event [:oli, :genai, :adaptive_context, :tool_called]

  describe "functions_for_session/1" do
    test "keeps the adaptive tool hidden outside supported adaptive sessions" do
      refute function_names(%{adaptive?: true}) |> Enum.member?("adaptive_page_context")
      refute function_names(%{}) |> Enum.member?("adaptive_page_context")
    end

    test "exposes the adaptive tool only when adaptive session context is complete" do
      handler = attach_telemetry([@tool_exposed_event])

      assert function_names(%{adaptive?: true, current_user_id: 12, section_id: 34})
             |> Enum.member?("adaptive_page_context")

      assert_receive {:telemetry_event, @tool_exposed_event, %{count: 1}, metadata}
      assert metadata.section_id == 34

      :telemetry.detach(handler)
    end
  end

  describe "adaptive_page_context/1" do
    test "fails closed on invalid arguments" do
      handler = attach_telemetry([@tool_called_event])

      assert StudentFunctions.adaptive_page_context(%{
               "activity_attempt_guid" => " ",
               "current_user_id" => "bad",
               "section_id" => "oops"
             }) == fail_closed_message()

      assert_receive {:telemetry_event, @tool_called_event, %{count: 1}, metadata}
      assert metadata.section_id == nil

      :telemetry.detach(handler)
    end
  end

  defp attach_telemetry(events) do
    handler_id = "student-functions-telemetry-test-#{System.unique_integer([:positive])}"
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

  defp function_names(session_context) do
    StudentFunctions.functions_for_session(session_context)
    |> Enum.map(& &1.name)
  end

  defp fail_closed_message do
    "Adaptive page context is unavailable for this request.\nAnswer only from other available lesson context and do not infer unseen adaptive screens."
  end
end
