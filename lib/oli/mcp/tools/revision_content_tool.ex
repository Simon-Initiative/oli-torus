defmodule Oli.MCP.Tools.RevisionContentTool do
  @moduledoc """
  MCP tool for retrieving JSON content of a resource revision.

  This tool allows external AI agents to retrieve content from any revision
  in any project for course authoring purposes.
  """

  use Hermes.Server.Component, type: :tool

  alias Oli.Publishing.AuthoringResolver
  alias Hermes.Server.Response
  alias Oli.GenAI.Agent.MCPToolRegistry
  alias Oli.MCP.Auth.Authorization

  # Get field descriptions from MCPToolRegistry at compile time
  @tool_schema MCPToolRegistry.get_tool_schema("revision_content")
  @project_slug_desc get_in(@tool_schema, ["properties", "project_slug", "description"])
  @revision_slug_desc get_in(@tool_schema, ["properties", "revision_slug", "description"])

  schema do
    field :project_slug, :string, required: true, description: @project_slug_desc
    field :revision_slug, :string, required: true, description: @revision_slug_desc
  end

  @impl true
  def execute(%{project_slug: project_slug, revision_slug: revision_slug}, frame) do
    # Validate project access before proceeding
    case Authorization.validate_project_access(project_slug) do
      {:ok, _auth_context} ->
        case get_revision_content(project_slug, revision_slug) do
          {:ok, json_content} ->
            {:reply, Response.text(Response.tool(), json_content), frame}

          {:error, reason} ->
            {:reply, Response.error(Response.tool(), reason), frame}
        end

      {:error, reason} ->
        {:reply, Response.error(Response.tool(), "Authorization failed: #{reason}"), frame}
    end
  end

  # Retrieves the JSON content of a resource revision
  defp get_revision_content(project_slug, revision_slug) do
    case AuthoringResolver.from_revision_slug(project_slug, revision_slug) do
      nil ->
        {:error, "Revision not found: project '#{project_slug}', revision '#{revision_slug}'"}

      %{deleted: true} ->
        {:error,
         "Revision has been deleted: project '#{project_slug}', revision '#{revision_slug}'"}

      %{content: content} ->
        case Jason.encode(content, pretty: true) do
          {:ok, json_string} ->
            {:ok, json_string}

          {:error, reason} ->
            {:error, "Failed to encode content as JSON: #{inspect(reason)}"}
        end
    end
  end
end
