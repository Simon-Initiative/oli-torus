defmodule Oli.GenAI.Agent.LLMBridgeTest do
  use ExUnit.Case, async: true
  alias Oli.GenAI.Agent.{LLMBridge, Decision, ToolBroker}
  alias Oli.GenAI.Completions.{ServiceConfig, RegisteredModel}
  import Mox

  setup :verify_on_exit!

  describe "select_models/1" do
    test "selects primary and fallback models from ServiceConfig" do
      config = %ServiceConfig{
        primary_model: %RegisteredModel{
          model: "test-primary",
          provider: :null,
          url_template: "http://localhost",
          api_key: "test-key",
          secondary_api_key: "test-org",
          timeout: 8000,
          recv_timeout: 60000
        },
        backup_model: %RegisteredModel{
          model: "test-backup",
          provider: :null,
          url_template: "http://localhost",
          api_key: "test-key-backup",
          secondary_api_key: "test-org-backup",
          timeout: 8000,
          recv_timeout: 60000
        }
      }

      assert {:ok, primary, fallbacks} = LLMBridge.select_models(config)
      assert primary.model == "test-primary"
      assert length(fallbacks) == 1
      assert hd(fallbacks).model == "test-backup"
    end

    test "handles config with no fallbacks" do
      config = %ServiceConfig{
        primary_model: %RegisteredModel{
          model: "test-primary",
          provider: :null,
          url_template: "http://localhost",
          api_key: "test-key",
          secondary_api_key: "test-org",
          timeout: 8000,
          recv_timeout: 60000
        },
        backup_model: nil
      }

      assert {:ok, primary, fallbacks} = LLMBridge.select_models(config)
      assert primary.model == "test-primary"
      assert fallbacks == []
    end

    test "returns error for config missing primary model" do
      config = %ServiceConfig{
        primary_model: nil,
        backup_model: nil
      }

      assert {:error, "ServiceConfig missing primary model"} = LLMBridge.select_models(config)
    end

    test "returns error for invalid config" do
      assert {:error, "Invalid service config"} = LLMBridge.select_models(%{})
      assert {:error, "Invalid service config"} = LLMBridge.select_models(nil)
    end
  end

  describe "call_provider/3" do
    setup do
      # Start ToolBroker if not already running
      ToolBroker.start()

      model = %RegisteredModel{
        model: "test-model",
        provider: :null,
        url_template: "http://localhost",
        api_key: "test-key",
        secondary_api_key: "test-org",
        timeout: 8000,
        recv_timeout: 60000
      }

      messages = [
        %{role: :system, content: "You are a helpful assistant"},
        %{role: :user, content: "Hello"}
      ]

      {:ok, model: model, messages: messages}
    end

    @tag :skip
    test "successfully calls provider with real completions", %{
      model: _model,
      messages: _messages
    } do
      # This test would require actual provider setup and mocking
      # Skipping as it requires integration with the real Completions module
      _opts = %{temperature: 0.7}

      # Would need to mock Oli.GenAI.Completions.generate/3
      # assert {:ok, response} = LLMBridge.call_provider(model, messages, opts)
    end
  end

  describe "next_decision/2" do
    setup do
      # Start ToolBroker if not already running
      ToolBroker.start()

      service_config = %ServiceConfig{
        primary_model: %RegisteredModel{
          model: "test-model",
          provider: :null,
          url_template: "http://localhost",
          api_key: "test-key",
          secondary_api_key: "test-org",
          timeout: 8000,
          recv_timeout: 60000
        },
        backup_model: %RegisteredModel{
          model: "backup-model",
          provider: :null,
          url_template: "http://localhost",
          api_key: "test-key-null",
          secondary_api_key: "test-org-null",
          timeout: 8000,
          recv_timeout: 60000
        }
      }

      messages = [
        %{role: :system, content: "You are an AI agent"},
        %{role: :user, content: "Search for main function"}
      ]

      {:ok, config: service_config, messages: messages}
    end

    test "requires service_config in opts", %{messages: messages} do
      # Should raise when service_config is missing
      assert_raise KeyError, fn ->
        LLMBridge.next_decision(messages, %{})
      end
    end

    @tag :skip
    test "accepts service_config with temperature", %{config: config, messages: _messages} do
      # Skip this test as it would call the NullProvider which returns mock responses
      # This is not a useful unit test for the LLMBridge functionality
      _opts = %{
        service_config: config,
        temperature: 0.5
      }

      # The NullProvider would return a mock response, but this doesn't test
      # the real LLMBridge logic in a meaningful way
      # assert {:ok, _decision} = LLMBridge.next_decision(messages, opts)
    end

    @tag :skip
    test "accepts service_config with max_tokens", %{config: config, messages: _messages} do
      # Skip this test as it would call the NullProvider which returns mock responses
      # This is not a useful unit test for the LLMBridge functionality
      _opts = %{
        service_config: config,
        max_tokens: 2000
      }

      # The NullProvider would return a mock response, but this doesn't test
      # the real LLMBridge logic in a meaningful way
      # assert {:ok, _decision} = LLMBridge.next_decision(messages, opts)
    end

    test "returns error when service_config has no primary model", %{messages: messages} do
      invalid_config = %ServiceConfig{
        primary_model: nil,
        backup_model: nil
      }

      opts = %{service_config: invalid_config}

      assert {:error, "ServiceConfig missing primary model"} =
               LLMBridge.next_decision(messages, opts)
    end
  end

  describe "Decision.from_completion/1" do
    test "parses OpenAI-style tool call response" do
      response = %{
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
                    "arguments" => ~s({"query":"main function"})
                  }
                }
              ]
            }
          }
        ]
      }

      assert {:ok, decision} = Decision.from_completion(response)
      assert decision.next_action == "tool"
      assert decision.tool_name == "search_codebase"
      assert decision.arguments == %{"query" => "main function"}
    end

    test "parses OpenAI-style message response" do
      response = %{
        "choices" => [
          %{
            "message" => %{
              "role" => "assistant",
              "content" => "I'll help you with that."
            }
          }
        ]
      }

      assert {:ok, decision} = Decision.from_completion(response)
      assert decision.next_action == "message"
      assert decision.assistant_message == "I'll help you with that."
    end

    test "parses normalized tool use response (formerly Anthropic-style)" do
      # This is what the Claude provider would return after normalization
      response = %{
        "choices" => [
          %{
            "index" => 0,
            "message" => %{
              "role" => "assistant",
              "content" => nil,
              "tool_calls" => [
                %{
                  "id" => "call_123",
                  "type" => "function",
                  "function" => %{
                    "name" => "read_file",
                    "arguments" => ~s({"file_path":"/src/main.ex"})
                  }
                }
              ]
            },
            "finish_reason" => "tool_calls"
          }
        ]
      }

      assert {:ok, decision} = Decision.from_completion(response)
      assert decision.next_action == "tool"
      assert decision.tool_name == "read_file"
      assert decision.arguments == %{"file_path" => "/src/main.ex"}
    end

    test "parses structured JSON response for replan" do
      response = %{
        "choices" => [
          %{
            "message" => %{
              "role" => "assistant",
              "content" =>
                ~s({"action":"replan","updated_plan":["step1","step2"],"rationale":"Need to adjust approach"})
            }
          }
        ]
      }

      assert {:ok, decision} = Decision.from_completion(response)
      assert decision.next_action == "replan"
      assert decision.updated_plan == ["step1", "step2"]
      assert decision.rationale_summary == "Need to adjust approach"
    end

    test "parses structured JSON response for done" do
      response = %{
        "choices" => [
          %{
            "message" => %{
              "role" => "assistant",
              "content" => ~s({"action":"done","rationale":"Task completed successfully"})
            }
          }
        ]
      }

      assert {:ok, decision} = Decision.from_completion(response)
      assert decision.next_action == "done"
      assert decision.rationale_summary == "Task completed successfully"
    end
  end
end
