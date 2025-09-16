defmodule Oli.MCP.ServerTest do
  use ExUnit.Case, async: true

  alias Oli.MCP.Server

  describe "Anubis MCP Server" do
    test "server has correct server info" do
      server_info = Server.server_info()

      assert %{"name" => "torus", "version" => "1.0.0"} = server_info
    end

    test "server has tools and resources capabilities" do
      capabilities = Server.server_capabilities()

      assert %{"tools" => %{}} = capabilities
      assert %{"resources" => %{}} = capabilities
    end

    test "server has all expected components registered" do
      # Get components using the public function
      components = Server.__components__()

      # Extract handler modules from the component structs
      handler_modules = Enum.map(components, & &1.handler)

      expected_tool_handlers = [
        Oli.MCP.Tools.ActivityValidationTool,
        Oli.MCP.Tools.ActivityTestEvalTool,
        Oli.MCP.Tools.CreateActivityTool
      ]

      expected_resource_handlers = [
        Oli.MCP.Resources.ProjectResources,
        Oli.MCP.Resources.SchemasResource,
        Oli.MCP.Resources.SchemaResource,
        Oli.MCP.Resources.ExamplesResource,
        Oli.MCP.Resources.ExampleResource
      ]

      all_expected = expected_tool_handlers ++ expected_resource_handlers

      for handler <- all_expected do
        assert handler in handler_modules, "#{handler} not found in registered components"
      end

      # Verify we have the expected number of components
      assert length(components) == length(all_expected)
    end

    test "all components have proper structure" do
      components = Server.__components__()

      for component <- components do
        case component do
          %Anubis.Server.Component.Tool{} = tool ->
            # Tool should have required fields
            assert is_binary(tool.name)
            assert is_binary(tool.description)
            assert is_map(tool.input_schema)
            assert is_atom(tool.handler)
            assert is_function(tool.validate_input)

          %Anubis.Server.Component.Resource{} = resource ->
            # Resource should have required fields
            assert is_binary(resource.uri) or is_binary(resource.uri_template)
            assert is_binary(resource.name)
            assert is_binary(resource.description)
            assert is_atom(resource.handler)
        end
      end
    end

    test "server supports MCP protocol version" do
      versions = Server.supported_protocol_versions()

      # Should support at least one version
      assert is_list(versions)
      assert length(versions) > 0
    end
  end
end
