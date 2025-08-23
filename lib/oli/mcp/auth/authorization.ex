defmodule Oli.MCP.Auth.Authorization do
  @moduledoc """
  Authorization helpers for MCP tools.

  Validates access permissions based on authentication context stored
  in the frame assigns by the MCP server's init callback.
  """

  alias Oli.Authoring.Course

  @doc """
  Validates that the authenticated user has access to the specified project.

  This function uses the authentication context from frame.assigns
  (set during MCP server initialization) to validate project access.

  Returns {:ok, %{author_id: id, project_id: id, project: project}} on success,
  {:error, reason} on failure.
  """
  def validate_project_access(project_slug, frame) do
    case frame.assigns do
      %{author_id: author_id, project_id: project_id} ->
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

      _ ->
        {:error, "No authentication context found"}
    end
  end

  @doc """
  Gets the authentication context for cross-project operations.

  Returns {:ok, %{author_id: id, project_id: id}} on success,
  {:error, reason} on failure.
  """
  def get_auth_context(frame) do
    case frame.assigns do
      %{author_id: author_id, project_id: project_id} ->
        {:ok, %{author_id: author_id, project_id: project_id}}

      _ ->
        {:error, "No authentication context found"}
    end
  end

  # Get project by slug
  defp get_project_by_slug(project_slug) do
    Course.get_project_by_slug(project_slug)
  end
end
