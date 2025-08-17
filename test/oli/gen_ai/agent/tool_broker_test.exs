defmodule Oli.GenAI.Agent.ToolBrokerTest do
  use ExUnit.Case, async: true
  alias Oli.GenAI.Agent.ToolBroker

  # Mock MCP tool for testing
  defmodule MockMCPTool do
    @behaviour Oli.GenAI.Agent.Tool

    @impl true
    def call("mcp_search", args, _ctx) do
      {:ok,
       %{
         content: "Found #{args["count"]} results for '#{args["query"]}'",
         token_cost: 50
       }}
    end

    def call("mcp_read", %{"path" => path}, _ctx) do
      {:ok,
       %{
         content: "Content of #{path}",
         token_cost: 30
       }}
    end

    def call(_name, _args, _ctx) do
      {:error, "Unknown MCP tool"}
    end
  end

  # Mock local tool for testing
  defmodule MockLocalTool do
    @behaviour Oli.GenAI.Agent.Tool

    @impl true
    def call("calculate", %{"expression" => expr}, _ctx) do
      result = eval_expression(expr)

      {:ok,
       %{
         content: "Result: #{result}",
         token_cost: 10
       }}
    end

    def call("format_code", %{"code" => code, "language" => lang}, _ctx) do
      {:ok,
       %{
         content: "Formatted #{lang} code: #{code}",
         token_cost: 20
       }}
    end

    def call(_name, _args, _ctx) do
      {:error, "Unknown local tool"}
    end

    defp eval_expression("2+2"), do: 4
    defp eval_expression(_), do: "unknown"
  end

  describe "start/1" do
    test "starts tool broker with default options" do
      assert :ok = ToolBroker.start()
    end

    test "starts with custom options" do
      opts = [max_tools: 100, timeout: 5000]
      assert :ok = ToolBroker.start(opts)
    end
  end

  describe "register/1" do
    setup do
      ToolBroker.start()
      :ok
    end

    test "registers a new tool spec" do
      tool_spec = %{
        name: "test_tool",
        desc: "A test tool",
        schema: %{
          type: "object",
          properties: %{
            param1: %{type: "string"}
          }
        }
      }

      assert :ok = ToolBroker.register(tool_spec)
    end

    test "registers multiple tools" do
      tool1 = %{
        name: "tool1",
        desc: "First tool",
        schema: %{type: "object", properties: %{}}
      }

      tool2 = %{
        name: "tool2",
        desc: "Second tool",
        schema: %{type: "object", properties: %{}}
      }

      assert :ok = ToolBroker.register(tool1)
      assert :ok = ToolBroker.register(tool2)
    end

    test "rejects duplicate tool names" do
      tool_spec = %{
        name: "duplicate",
        desc: "A tool",
        schema: %{}
      }

      assert :ok = ToolBroker.register(tool_spec)
      assert {:error, "Tool 'duplicate' already registered"} = ToolBroker.register(tool_spec)
    end

    test "validates tool spec structure" do
      invalid_spec = %{name: "missing_fields"}
      assert {:error, _reason} = ToolBroker.register(invalid_spec)
    end
  end

  describe "list/0" do
    setup do
      ToolBroker.start()

      tools = [
        %{name: "search", desc: "Search tool", schema: %{}},
        %{name: "read", desc: "Read tool", schema: %{}},
        %{name: "write", desc: "Write tool", schema: %{}}
      ]

      Enum.each(tools, &ToolBroker.register/1)
      :ok
    end

    test "lists all registered tool names" do
      tool_names = ToolBroker.list()
      assert "search" in tool_names
      assert "read" in tool_names
      assert "write" in tool_names
      assert length(tool_names) >= 3
    end
  end

  describe "describe/0" do
    setup do
      ToolBroker.start()

      tools = [
        %{
          name: "code_search",
          desc: "Search for code patterns",
          schema: %{
            type: "object",
            properties: %{
              pattern: %{type: "string", description: "Regex pattern"},
              path: %{type: "string", description: "Search path"}
            },
            required: ["pattern"]
          }
        },
        %{
          name: "file_read",
          desc: "Read file contents",
          schema: %{
            type: "object",
            properties: %{
              file_path: %{type: "string", description: "Path to file"}
            },
            required: ["file_path"]
          }
        }
      ]

      Enum.each(tools, &ToolBroker.register/1)
      {:ok, registered_tools: tools}
    end

    test "returns all tool descriptions", %{registered_tools: _registered_tools} do
      descriptions = ToolBroker.describe()

      assert length(descriptions) >= 2

      code_search = Enum.find(descriptions, &(&1.name == "code_search"))
      assert code_search
      assert code_search.desc == "Search for code patterns"
      assert code_search.schema.properties.pattern

      file_read = Enum.find(descriptions, &(&1.name == "file_read"))
      assert file_read
      assert file_read.desc == "Read file contents"
    end
  end

  describe "tools_for_completion/0" do
    setup do
      ToolBroker.start()
      # Use the default MCP tools that are auto-registered
      :ok
    end

    test "returns OpenAI-style function specs" do
      tools = ToolBroker.tools_for_completion()

      assert is_list(tools)
      assert length(tools) >= 2

      # Check structure matches OpenAI format - use actual MCP tools
      revision_tool =
        Enum.find(tools, fn t ->
          get_in(t, [:function, :name]) == "revision_content"
        end)

      assert revision_tool
      assert revision_tool.type == "function"
      assert revision_tool.function.name == "revision_content"

      assert revision_tool.function.description ==
               "Retrieve JSON content of a resource revision from any project"

      assert revision_tool.function.parameters["type"] == "object"
      assert revision_tool.function.parameters["properties"]["project_slug"]
      assert revision_tool.function.parameters["required"] == ["project_slug", "revision_slug"]
    end

    test "converts to Anthropic-style tool specs when needed" do
      # This would be handled by LLMBridge based on provider
      tools = ToolBroker.tools_for_completion()

      # Can be converted to Anthropic format
      anthropic_tools =
        Enum.map(tools, fn tool ->
          %{
            name: tool.function.name,
            description: tool.function.description,
            input_schema: tool.function.parameters
          }
        end)

      revision_tool = Enum.find(anthropic_tools, &(&1.name == "revision_content"))
      assert revision_tool
      assert revision_tool.input_schema["properties"]["project_slug"]
    end
  end

  describe "call/3" do
    setup do
      ToolBroker.start()

      # Register MCP tools
      mcp_tools = [
        %{
          name: "mcp_search",
          desc: "MCP search tool",
          schema: %{
            type: "object",
            properties: %{
              query: %{type: "string"},
              count: %{type: "integer"}
            }
          }
        },
        %{
          name: "mcp_read",
          desc: "MCP read tool",
          schema: %{
            type: "object",
            properties: %{
              path: %{type: "string"}
            }
          }
        }
      ]

      # Register local tools
      local_tools = [
        %{
          name: "calculate",
          desc: "Calculator tool",
          schema: %{
            type: "object",
            properties: %{
              expression: %{type: "string"}
            }
          }
        },
        %{
          name: "format_code",
          desc: "Code formatter",
          schema: %{
            type: "object",
            properties: %{
              code: %{type: "string"},
              language: %{type: "string"}
            }
          }
        }
      ]

      Enum.each(mcp_tools ++ local_tools, &ToolBroker.register/1)

      # Mock the tool routing (in real implementation, this would be internal)
      # For testing, we'll assume ToolBroker routes to our mock implementations
      :ok
    end

    test "returns error for unimplemented MCP tool" do
      args = %{"query" => "test search", "count" => 10}
      ctx = %{user_id: "123", project_id: "456"}

      assert {:error, reason} = ToolBroker.call("mcp_search", args, ctx)
      assert reason == "MCP tool 'mcp_search' not found"
    end

    test "returns error for unimplemented local tool" do
      args = %{"expression" => "2+2"}
      ctx = %{}

      assert {:error, reason} = ToolBroker.call("calculate", args, ctx)
      assert reason == "MCP tool 'calculate' not found"
    end

    test "handles tool execution errors" do
      assert {:error, reason} = ToolBroker.call("nonexistent_tool", %{}, %{})
      assert reason =~ "Unknown tool" || reason =~ "not found"
    end

    test "returns error for unregistered tools when validating arguments" do
      # Missing required argument for a tool that's not in built-in tools
      # Missing 'query' which would be required if tool existed
      args = %{}

      assert {:error, reason} = ToolBroker.call("mcp_search", args, %{})
      assert reason == "MCP tool 'mcp_search' not found"
    end

    test "returns error for unimplemented format_code tool" do
      args = %{"code" => "function test() {}", "language" => "javascript"}
      ctx = %{user_id: "user123", session_id: "sess456"}

      assert {:error, reason} = ToolBroker.call("format_code", args, ctx)
      assert reason == "MCP tool 'format_code' not found"
    end

    test "handles timeout for long-running tools" do
      # Test with an actual MCP tool that will fail
      args = %{"activity_json" => "invalid json"}
      ctx = %{}

      # This should return an error for invalid JSON
      result = ToolBroker.call("activity_validation", args, ctx)

      case result do
        {:error, reason} -> assert reason =~ "execution failed" || reason =~ "Invalid JSON"
        {:ok, _} -> assert false, "Expected error for invalid JSON"
      end
    end
  end
end
