defmodule Oli.GenAI.Agent.DecisionTest do
  use ExUnit.Case, async: true
  alias Oli.GenAI.Agent.Decision

  describe "from_completion/1" do
    test "parses OpenAI-style function call" do
      openai_payload = %{
        "choices" => [
          %{
            "message" => %{
              "role" => "assistant",
              "content" => nil,
              "tool_calls" => [
                %{
                  "id" => "call_123",
                  "type" => "function",
                  "function" => %{
                    "name" => "search_codebase",
                    "arguments" => ~s({"query":"find main function","path":"src/"})
                  }
                }
              ]
            }
          }
        ]
      }

      assert {:ok, decision} = Decision.from_completion(openai_payload)
      assert decision.next_action == "tool"
      assert decision.tool_name == "search_codebase"
      assert decision.arguments == %{"query" => "find main function", "path" => "src/"}
    end

    test "parses Anthropic-style function call" do
      anthropic_payload = %{
        "content" => [
          %{
            "type" => "tool_use",
            "id" => "toolu_123",
            "name" => "get_weather",
            "input" => %{"location" => "San Francisco", "unit" => "celsius"}
          }
        ],
        "role" => "assistant"
      }

      assert {:ok, decision} = Decision.from_completion(anthropic_payload)
      assert decision.next_action == "tool"
      assert decision.tool_name == "get_weather"
      assert decision.arguments == %{"location" => "San Francisco", "unit" => "celsius"}
    end

    test "parses plain assistant message" do
      plain_payload = %{
        "choices" => [
          %{
            "message" => %{
              "role" => "assistant",
              "content" => "I'll help you with that task."
            }
          }
        ]
      }

      assert {:ok, decision} = Decision.from_completion(plain_payload)
      assert decision.next_action == "message"
      assert decision.assistant_message == "I'll help you with that task."
      assert is_nil(decision.tool_name)
      assert is_nil(decision.arguments)
    end

    test "parses replan action from structured response" do
      replan_payload = %{
        "choices" => [
          %{
            "message" => %{
              "role" => "assistant",
              "content" =>
                ~s({"action": "replan", "updated_plan": ["step1", "step2", "step3"], "rationale": "Need to adjust approach"})
            }
          }
        ]
      }

      assert {:ok, decision} = Decision.from_completion(replan_payload)
      assert decision.next_action == "replan"
      assert decision.updated_plan == ["step1", "step2", "step3"]
      assert decision.rationale_summary == "Need to adjust approach"
    end

    test "parses done action" do
      done_payload = %{
        "choices" => [
          %{
            "message" => %{
              "role" => "assistant",
              "content" => ~s({"action": "done", "rationale": "Task completed successfully"})
            }
          }
        ]
      }

      assert {:ok, decision} = Decision.from_completion(done_payload)
      assert decision.next_action == "done"
      assert decision.rationale_summary == "Task completed successfully"
    end

    test "handles malformed payload" do
      bad_payload = %{"invalid" => "structure"}
      assert {:error, _reason} = Decision.from_completion(bad_payload)
    end
  end

  describe "new/1" do
    test "creates decision from map" do
      attrs = %{
        next_action: "tool",
        tool_name: "test_tool",
        arguments: %{"arg" => "value"}
      }

      decision = Decision.new(attrs)
      assert decision.next_action == "tool"
      assert decision.tool_name == "test_tool"
      assert decision.arguments == %{"arg" => "value"}
    end

    test "creates decision with partial attributes" do
      attrs = %{next_action: "message", assistant_message: "Hello"}
      decision = Decision.new(attrs)
      assert decision.next_action == "message"
      assert decision.assistant_message == "Hello"
      assert is_nil(decision.tool_name)
    end
  end

  describe "validate/1" do
    test "validates tool decision requires tool_name and arguments" do
      valid_tool = %Decision{
        next_action: "tool",
        tool_name: "search",
        arguments: %{}
      }

      assert :ok = Decision.validate(valid_tool)

      invalid_tool = %Decision{
        next_action: "tool",
        tool_name: nil,
        arguments: %{}
      }

      assert {:error, errors} = Decision.validate(invalid_tool)
      assert "tool_name is required for tool action" in errors
    end

    test "validates message decision requires assistant_message" do
      valid_message = %Decision{
        next_action: "message",
        assistant_message: "Hello"
      }

      assert :ok = Decision.validate(valid_message)

      invalid_message = %Decision{
        next_action: "message",
        assistant_message: nil
      }

      assert {:error, errors} = Decision.validate(invalid_message)
      assert "assistant_message is required for message action" in errors
    end

    test "validates replan decision requires updated_plan" do
      valid_replan = %Decision{
        next_action: "replan",
        updated_plan: ["step1", "step2"],
        rationale_summary: "Adjusting approach"
      }

      assert :ok = Decision.validate(valid_replan)

      invalid_replan = %Decision{
        next_action: "replan",
        updated_plan: nil
      }

      assert {:error, errors} = Decision.validate(invalid_replan)
      assert "updated_plan is required for replan action" in errors
    end

    test "validates done decision" do
      valid_done = %Decision{
        next_action: "done",
        rationale_summary: "Completed"
      }

      assert :ok = Decision.validate(valid_done)
    end

    test "rejects invalid action type" do
      invalid_action = %Decision{
        next_action: "invalid_action"
      }

      assert {:error, errors} = Decision.validate(invalid_action)
      assert "invalid action type: invalid_action" in errors
    end
  end

  describe "helper functions" do
    test "tool?/1 checks if decision is a tool action" do
      tool_decision = %Decision{next_action: "tool"}
      assert Decision.tool?(tool_decision)

      message_decision = %Decision{next_action: "message"}
      refute Decision.tool?(message_decision)
    end

    test "message?/1 checks if decision is a message action" do
      message_decision = %Decision{next_action: "message"}
      assert Decision.message?(message_decision)

      tool_decision = %Decision{next_action: "tool"}
      refute Decision.message?(tool_decision)
    end

    test "done?/1 checks if decision is done" do
      done_decision = %Decision{next_action: "done"}
      assert Decision.done?(done_decision)

      tool_decision = %Decision{next_action: "tool"}
      refute Decision.done?(tool_decision)
    end
  end
end
