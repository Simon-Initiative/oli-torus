defmodule Oli.GenAI.Tools.ContentSchemaTool do
  @moduledoc """
  MCP tool for retrieving the content element JSON schema.

  This tool exposes the JSON schema that defines the structure of rich content
  elements used throughout the Torus platform, helping external AI agents
  understand how to structure content properly.
  """

  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response

  # Schema definition maintained in MCPToolRegistry for consistency
  # (content_schema tool requires no input parameters)

  schema do
    # No input parameters required - always returns the same schema
    # Schema definition maintained in MCPToolRegistry for consistency
  end

  @impl true
  def execute(_params, frame) do
    case get_content_schema() do
      {:ok, schema_json} ->
        {:reply, Response.text(Response.tool(), schema_json), frame}

      {:error, reason} ->
        {:reply, Response.error(Response.tool(), reason), frame}
    end
  end

  # Reads and returns the content element schema
  defp get_content_schema do
    schema_path = Application.app_dir(:oli, "priv/schemas/v0-1-0/content-element.schema.json")

    case File.read(schema_path) do
      {:ok, content} ->
        # Validate it's proper JSON and pretty-format it
        case Jason.decode(content) do
          {:ok, schema} ->
            {:ok, Jason.encode!(schema, pretty: true)}

          {:error, reason} ->
            {:error, "Failed to parse schema file as JSON: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, "Failed to read content schema file: #{inspect(reason)}"}
    end
  end
end
