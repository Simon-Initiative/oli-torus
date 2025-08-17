defmodule Oli.MCP.Server do
  @moduledoc """
  MCP (Model Context Protocol) server for external AI agents to interact with Torus.

  This server provides tools for external AI agents to retrieve and work with
  Torus content, enabling them to author course materials.

  Uses Hermes MCP v0.14.1 for MCP protocol implementation.

  Authentication is handled by the ValidateMCPBearerToken plug which sets
  authentication context in the connection assigns.
  """

  use Hermes.Server,
    name: "oli-torus",
    version: "1.0.0",
    capabilities: [:tools]

  # Register our tools
  component(Oli.MCP.Tools.RevisionContentTool)
  component(Oli.MCP.Tools.ActivityValidationTool)
  component(Oli.MCP.Tools.ActivityTestEvalTool)
  component(Oli.MCP.Tools.ExampleActivityTool)
  component(Oli.MCP.Tools.CreateActivityTool)
  component(Oli.MCP.Tools.ContentSchemaTool)
end
