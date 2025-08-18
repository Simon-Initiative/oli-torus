defmodule Oli.MCP.Server do
  @moduledoc """
  MCP (Model Context Protocol) server for external AI agents to interact with Torus.

  This server provides tools for external AI agents to retrieve and work with
  Torus content, enabling them to author course materials.

  Uses Anubis MCP v0.13.1 for MCP protocol implementation.

  Authentication is handled directly in the init/2 callback by validating
  Bearer tokens from the Authorization header.
  """

  use Anubis.Server,
    name: "torus",
    version: "1.0.0",
    capabilities: [:tools, :resources]

  alias Oli.MCP.Auth

  # Register our resources
  component(Oli.MCP.Resources.ProjectResources)
  component(Oli.MCP.Resources.SchemasResource)
  component(Oli.MCP.Resources.SchemaResource)
  component(Oli.MCP.Resources.ExamplesResource)
  component(Oli.MCP.Resources.ExampleResource)

  # Register our tools
  component(Oli.MCP.Tools.ActivityValidationTool)
  component(Oli.MCP.Tools.ActivityTestEvalTool)
  component(Oli.MCP.Tools.CreateActivityTool)

  @impl true
  def init(_arg, frame) do
    # Extract Bearer token from Authorization header
    case Enum.find(frame.transport.req_headers, fn {h, _v} -> h == "authorization" end) do

      nil ->
        {:stop, :unauthorized}

      {_, bearer_token} ->
        case extract_and_validate_token(bearer_token) do
          {:ok, auth_context} ->
            # Store authentication context in frame assigns
            {:ok, Map.put(frame, :assigns, auth_context)}

          :error ->
            {:stop, :unauthorized}
        end

    end

  end

  defp extract_and_validate_token("Bearer " <> token) do
    case Auth.validate_token(token) do
      {:ok, %{author_id: author_id, project_id: project_id}} ->
        {:ok, %{author_id: author_id, project_id: project_id, bearer_token: token}}

      {:error, _reason} ->
        :error
    end
  end

  defp extract_and_validate_token(_), do: :error
end
