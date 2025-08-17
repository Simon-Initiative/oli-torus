defmodule Oli.MCP.Auth.Authorization do
  @moduledoc """
  Authorization helpers for MCP tools.

  Since the Hermes framework doesn't directly expose Plug.Conn context to tools,
  we implement authorization by having tools re-validate their access permissions
  based on the Bearer token in the request headers.
  """

  alias Oli.MCP.Auth
  alias Oli.Authoring.Course

  @doc """
  Validates that a Bearer token grants access to the specified project.

  This function extracts the Bearer token from the current process context
  (set by Process.put/2 in the MCP plug) and validates project access.

  Returns {:ok, %{author_id: id, project_id: id}} on success,
  {:error, reason} on failure.
  """
  def validate_project_access(project_slug) do
    case Process.get(:mcp_bearer_token) do
      nil ->
        {:error, "No MCP Bearer token found in request context"}

      token ->
        case Auth.validate_token(token) do
          {:ok, %{author_id: author_id, project_id: project_id}} ->
            case get_project_by_slug(project_slug) do
              nil ->
                {:error, "Project not found: #{project_slug}"}

              project ->
                if project.id == project_id do
                  {:ok, %{author_id: author_id, project_id: project_id, project: project}}
                else
                  {:error, "Bearer token does not grant access to project: #{project_slug}"}
                end
            end

          {:error, reason} ->
            {:error, "Invalid Bearer token: #{reason}"}
        end
    end
  end

  @doc """
  Validates that a Bearer token grants access to any project (for cross-project operations).

  Returns {:ok, %{author_id: id, project_id: id}} on success,
  {:error, reason} on failure.
  """
  def validate_any_project_access do
    case Process.get(:mcp_bearer_token) do
      nil ->
        {:error, "No MCP Bearer token found in request context"}

      token ->
        Auth.validate_token(token)
    end
  end

  # Get project by slug
  defp get_project_by_slug(project_slug) do
    Course.get_project_by_slug(project_slug)
  end
end
