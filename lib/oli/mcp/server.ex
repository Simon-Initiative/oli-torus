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
    capabilities: [:tools, :resources]

  # Register our tools
  component(Oli.MCP.Tools.RevisionContentTool)
  component(Oli.MCP.Tools.ActivityValidationTool)
  component(Oli.MCP.Tools.ActivityTestEvalTool)
  component(Oli.MCP.Tools.ExampleActivityTool)
  component(Oli.MCP.Tools.CreateActivityTool)
  component(Oli.MCP.Tools.ContentSchemaTool)

  @impl true
  def handle_resource_read(uri, frame) do
    Oli.MCP.Resources.ProjectResources.read(%{"uri" => uri}, frame)
  end

  @impl true
  def init(_opts, frame) do
    # For now, we just return the frame as-is
    # Resource templates are handled through the resource read mechanism
    {:ok, frame}
  end
end
