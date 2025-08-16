defmodule Oli.GenAI.Tools.RevisionContentTool do
  @moduledoc """
  MCP tool for retrieving JSON content of a resource revision.
  
  This tool allows external AI agents to retrieve content from any revision
  in any project for course authoring purposes.
  """
  
  use Hermes.Server.Component, type: :tool
  
  alias Oli.Publishing.AuthoringResolver
  alias Hermes.Server.Response

  schema do
    field :project_slug, :string, required: true, description: "The slug of the project containing the revision"
    field :revision_slug, :string, required: true, description: "The slug of the revision to retrieve content from"
  end

  @impl true
  def execute(%{project_slug: project_slug, revision_slug: revision_slug}, frame) do
    case get_revision_content(project_slug, revision_slug) do
      {:ok, json_content} ->
        {:reply, Response.text(Response.tool(), json_content), frame}
        
      {:error, reason} ->
        {:reply, Response.error(Response.tool(), reason), frame}
    end
  end

  # Retrieves the JSON content of a resource revision
  defp get_revision_content(project_slug, revision_slug) do
    case AuthoringResolver.from_revision_slug(project_slug, revision_slug) do
      nil ->
        {:error, "Revision not found: project '#{project_slug}', revision '#{revision_slug}'"}
        
      %{deleted: true} ->
        {:error, "Revision has been deleted: project '#{project_slug}', revision '#{revision_slug}'"}
        
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