defmodule Oli.MCPTestHelpers do
  @moduledoc """
  Test helpers for MCP authentication and tools testing.
  """

  alias Oli.MCP.Auth

  @doc """
  Sets up Bearer token authentication context for MCP tool tests.
  
  This function creates a Bearer token for the given author and project,
  then stores it in the process context so MCP tools can access it.
  
  Returns the token string for reference.
  """
  def setup_mcp_auth_context(author_id, project_id) do
    # Create a Bearer token for the author and project
    {:ok, {_bearer_token, token_string}} = Auth.create_token(author_id, project_id, "Test token")
    
    # Store token in process context (same as the plug does)
    Process.put(:mcp_bearer_token, token_string)
    
    token_string
  end

  @doc """
  Clears the MCP authentication context from the process.
  """
  def clear_mcp_auth_context do
    Process.delete(:mcp_bearer_token)
  end

  @doc """
  Wraps a test function with MCP authentication context.
  
  Usage:
    with_mcp_auth(author.id, project.id, fn ->
      # test code that calls MCP tools
    end)
  """
  def with_mcp_auth(author_id, project_id, test_func) do
    token = setup_mcp_auth_context(author_id, project_id)
    
    try do
      test_func.()
    after
      clear_mcp_auth_context()
    end
    
    token
  end
end