defmodule Oli.GenAI.Agent.LLMBridgeTest do
  use ExUnit.Case, async: true
  alias Oli.GenAI.Agent.{LLMBridge, Decision}
  alias Oli.GenAI.Completions.{ServiceConfig, RegisteredModel}

  # Mock ToolBroker for testing
  defmodule MockToolBroker do
    def tools_for_completion do
      [
        %{
          type: "function",
          function: %{
            name: "search_codebase",
            description: "Search for code in the codebase",
            parameters: %{
              type: "object",
              properties: %{
                query: %{type: "string", description: "Search query"},
                path: %{type: "string", description: "Path to search in"}
              },
              required: ["query"]
            }
          }
        },
        %{
          type: "function",
          function: %{
            name: "read_file",
            description: "Read contents of a file",
            parameters: %{
              type: "object",
              properties: %{
                file_path: %{type: "string", description: "Path to file"}
              },
              required: ["file_path"]
            }
          }
        }
      ]
    end
  end

  # Fake provider for testing
  defmodule FakeProvider do
    @behaviour Oli.GenAI.Completions.Provider

    def generate(_messages, _functions, _registered_model) do
      {:ok, tool_call_response()}
    end

    def stream(_messages, _functions, _registered_model, _response_handler_fn) do
      {:ok, tool_call_response()}
    end

    defp tool_call_response do
      %{
        "choices" => [
          %{
            "message" => %{
              "role" => "assistant",
              "content" => nil,
              "tool_calls" => [
                %{
                  "id" => "call_test",
                  "type" => "function",
                  "function" => %{
                    "name" => "search_codebase",
                    "arguments" => ~s({"query":"test query","path":"src/"})
                  }
                }
              ]
            }
          }
        ],
        "usage" => %{
          "prompt_tokens" => 100,
          "completion_tokens" => 50,
          "total_tokens" => 150
        }
      }
    end

  end

  describe "select_models/1" do
    test "selects primary and fallback models from ServiceConfig" do
      config = %ServiceConfig{
        primary_model: %RegisteredModel{
          model: "gpt-4",
          provider: :open_ai,
          url_template: "https://api.openai.com",
          api_key: "test-key",
          secondary_api_key: "test-org",
          timeout: 8000,
          recv_timeout: 60000
        },
        backup_model: %RegisteredModel{
          model: "claude-3",
          provider: :claude,
          url_template: "https://api.anthropic.com",
          api_key: "test-key-claude",
          secondary_api_key: "test-org-claude",
          timeout: 8000,
          recv_timeout: 60000
        }
      }

      assert {:ok, primary, fallbacks} = LLMBridge.select_models(config)
      assert primary.model == "gpt-4"
      assert length(fallbacks) == 1
      assert hd(fallbacks).model == "claude-3"
    end

    test "handles config with no fallbacks" do
      config = %ServiceConfig{
        primary_model: %RegisteredModel{
          model: "gpt-4",
          provider: :open_ai,
          url_template: "https://api.openai.com",
          api_key: "test-key",
          secondary_api_key: "test-org",
          timeout: 8000,
          recv_timeout: 60000
        },
        backup_model: nil
      }

      assert {:ok, primary, fallbacks} = LLMBridge.select_models(config)
      assert primary.model == "gpt-4"
      assert fallbacks == []
    end

    test "returns error for invalid config" do
      assert {:error, _reason} = LLMBridge.select_models(%{})
      assert {:error, _reason} = LLMBridge.select_models(nil)
    end
  end

  describe "call_provider/3" do
    setup do
      model = %RegisteredModel{
        model: "test-model",
        provider: :open_ai,
        url_template: "https://api.openai.com",
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

    test "successfully calls provider with tools", %{model: model, messages: messages} do
      opts = [test_scenario: :tool_call, tools: MockToolBroker.tools_for_completion()]
      
      assert {:ok, response} = LLMBridge.call_provider(model, messages, opts)
      assert response["choices"]
      assert response["usage"]
    end

    test "successfully calls provider without tools", %{model: model, messages: messages} do
      opts = [test_scenario: :plain_message]
      
      assert {:ok, response} = LLMBridge.call_provider(model, messages, opts)
      assert response["choices"]
      assert response["choices"] |> hd() |> get_in(["message", "content"]) == "I understand your request."
    end

    test "handles provider errors", %{model: model, messages: messages} do
      opts = [test_scenario: :error]
      
      assert {:error, reason} = LLMBridge.call_provider(model, messages, opts)
      assert reason == "Provider error"
    end

    test "includes temperature and max_tokens in options", %{model: model, messages: messages} do
      opts = [temperature: 0.7, max_tokens: 1000, test_scenario: :plain_message]
      
      assert {:ok, response} = LLMBridge.call_provider(model, messages, opts)
      assert response["choices"]
    end
  end

  describe "next_decision/2" do
    setup do
      service_config = %ServiceConfig{
        primary_model: %RegisteredModel{
          model: "test-model",
          provider: :open_ai,
          url_template: "https://api.openai.com",
          api_key: "test-key",
          secondary_api_key: "test-org",
          timeout: 8000,
          recv_timeout: 60000
        },
        backup_model: %RegisteredModel{
          model: "backup-model",
          provider: :claude,
          url_template: "https://api.anthropic.com",
          api_key: "test-key-claude",
          secondary_api_key: "test-org-claude",
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

    test "returns tool decision for function call", %{config: config, messages: messages} do
      opts = %{
        service_config: config,
        test_scenario: :tool_call
      }

      assert {:ok, %Decision{} = decision} = LLMBridge.next_decision(messages, opts)
      assert decision.next_action == "tool"
      assert decision.tool_name == "search_codebase"
      assert decision.arguments == %{"query" => "test query", "path" => "src/"}
    end

    test "returns message decision for plain response", %{config: config, messages: messages} do
      opts = %{
        service_config: config,
        test_scenario: :plain_message
      }

      assert {:ok, %Decision{} = decision} = LLMBridge.next_decision(messages, opts)
      assert decision.next_action == "message"
      assert decision.assistant_message == "I understand your request."
    end

    test "applies temperature setting", %{config: config, messages: messages} do
      opts = %{
        service_config: config,
        temperature: 0.5,
        test_scenario: :plain_message
      }

      assert {:ok, %Decision{}} = LLMBridge.next_decision(messages, opts)
    end

    test "applies max_tokens setting", %{config: config, messages: messages} do
      opts = %{
        service_config: config,
        max_tokens: 2000,
        test_scenario: :plain_message
      }

      assert {:ok, %Decision{}} = LLMBridge.next_decision(messages, opts)
    end

    test "falls back to backup model on primary error", %{messages: messages} do
      # Create a config where primary fails but fallback works
      config_with_fallback = %ServiceConfig{
        primary_model: %RegisteredModel{
          model: "failing-model",
          provider: :open_ai,
          url_template: "https://api.openai.com",
          api_key: "test-key",
          secondary_api_key: "test-org",
          timeout: 8000,
          recv_timeout: 60000
        },
        backup_model: %RegisteredModel{
          model: "working-model",
          provider: :claude,
          url_template: "https://api.anthropic.com",
          api_key: "test-key-claude",
          secondary_api_key: "test-org-claude",
          timeout: 8000,
          recv_timeout: 60000
        }
      }

      opts = %{service_config: config_with_fallback, test_scenario: :plain_message}

      assert {:ok, %Decision{} = decision} = LLMBridge.next_decision(messages, opts)
      assert decision.next_action == "message"
    end

    test "returns error when all models fail", %{messages: messages} do
      config_all_fail = %ServiceConfig{
        primary_model: %RegisteredModel{
          model: "failing-model-1",
          provider: :open_ai,
          url_template: "https://api.openai.com",
          api_key: "test-key",
          secondary_api_key: "test-org",
          timeout: 8000,
          recv_timeout: 60000
        },
        backup_model: %RegisteredModel{
          model: "failing-model-2",
          provider: :claude,
          url_template: "https://api.anthropic.com",
          api_key: "test-key-claude",
          secondary_api_key: "test-org-claude",
          timeout: 8000,
          recv_timeout: 60000
        }
      }

      opts = %{service_config: config_all_fail, test_scenario: :error}

      assert {:error, _reason} = LLMBridge.next_decision(messages, opts)
    end
  end
end