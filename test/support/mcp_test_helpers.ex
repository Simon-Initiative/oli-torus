defmodule Oli.MCPTestHelpers do
  @moduledoc """
  Test helpers for MCP authentication and tools testing.
  """

  alias Oli.MCP.Auth

  @doc """
  Creates a test frame with authentication context for MCP tool tests.

  This function creates a Bearer token for the given author and project,
  then returns a frame struct with the authentication context in assigns.

  Returns {frame, token_string} for reference.
  """
  def create_authenticated_frame(author_id, project_id) do
    # Create a Bearer token for the author and project
    {:ok, {_bearer_token, token_string}} = Auth.create_token(author_id, project_id, "Test token")

    # Create a frame with authentication context in assigns
    frame = %{
      assigns: %{
        author_id: author_id,
        project_id: project_id,
        bearer_token: token_string
      },
      transport: %{
        headers: %{
          "authorization" => "Bearer #{token_string}"
        }
      }
    }

    {frame, token_string}
  end

  @doc """
  Creates a basic frame without authentication for testing unauthorized access.
  """
  def create_unauthenticated_frame do
    %{
      assigns: %{},
      transport: %{
        headers: %{}
      }
    }
  end

  @doc """
  Wraps a test function with an authenticated frame.

  Usage:
    with_authenticated_frame(author.id, project.id, fn frame ->
      # test code that uses the frame
    end)
  """
  def with_authenticated_frame(author_id, project_id, test_func) do
    {frame, token} = create_authenticated_frame(author_id, project_id)
    test_func.(frame)
    token
  end
end
