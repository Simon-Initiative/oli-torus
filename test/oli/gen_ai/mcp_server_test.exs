defmodule Oli.GenAI.MCPServerTest do
  use ExUnit.Case, async: true

  alias Oli.GenAI.MCPServer

  describe "Hermes MCP Server" do
    test "server has correct server info" do
      server_info = MCPServer.server_info()
      
      assert %{"name" => "oli-torus", "version" => "1.0.0"} = server_info
    end

    test "server has tools capability" do
      capabilities = MCPServer.server_capabilities()
      
      assert %{"tools" => %{}} = capabilities
    end

    test "server has all expected tool components registered" do
      # Get components using the public function
      components = MCPServer.__components__()
      
      # Extract handler modules from the component structs
      handler_modules = Enum.map(components, & &1.handler)
      
      expected_handlers = [
        Oli.GenAI.Tools.RevisionContentTool,
        Oli.GenAI.Tools.ActivityValidationTool,
        Oli.GenAI.Tools.ActivityTestEvalTool,
        Oli.GenAI.Tools.ExampleActivityTool,
        Oli.GenAI.Tools.CreateActivityTool,
        Oli.GenAI.Tools.ContentSchemaTool
      ]
      
      for handler <- expected_handlers do
        assert handler in handler_modules, "#{handler} not found in registered components"
      end
      
      # Verify we have the expected number of components
      assert length(components) == length(expected_handlers)
    end

    test "all tools have proper structure" do
      components = MCPServer.__components__()
      
      for component <- components do
        # Each component should be a Hermes Tool struct
        assert %Hermes.Server.Component.Tool{} = component
        
        # Should have required fields
        assert is_binary(component.name)
        assert is_binary(component.description)
        assert is_map(component.input_schema)
        assert is_atom(component.handler)
        assert is_function(component.validate_input)
      end
    end

    test "server supports MCP protocol version" do
      versions = MCPServer.supported_protocol_versions()
      
      # Should support at least one version
      assert is_list(versions)
      assert length(versions) > 0
    end
  end
end