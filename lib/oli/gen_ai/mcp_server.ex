defmodule Oli.GenAI.MCPServer do
  @moduledoc """
  MCP (Model Context Protocol) server for external AI agents to interact with Torus.

  This server provides tools for external AI agents to retrieve and work with
  Torus content, enabling them to author course materials.

  Uses Hermes MCP v0.14.1 for MCP protocol implementation.
  """

  use Hermes.Server,
    name: "oli-torus",
    version: "1.0.0",
    capabilities: [:tools]

  # Register our tools
  component(Oli.GenAI.Tools.RevisionContentTool)
  component(Oli.GenAI.Tools.ActivityValidationTool)
  component(Oli.GenAI.Tools.ActivityTestEvalTool)
  component(Oli.GenAI.Tools.ExampleActivityTool)
  component(Oli.GenAI.Tools.CreateActivityTool)
  component(Oli.GenAI.Tools.ContentSchemaTool)
end
