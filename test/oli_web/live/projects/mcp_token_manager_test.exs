defmodule OliWeb.Projects.MCPTokenManagerTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.MCP.Auth

  describe "MCP Token Manager" do
    setup [:author_conn]

    test "displays MCP section on overview page", %{conn: conn, author: author} do
      project = create_project_with_author(author)
      {:ok, view, html} = live(conn, ~p"/workspaces/course_author/#{project.slug}/overview")

      # Check that the MCP section exists
      assert html =~ "MCP Access Tokens"
      assert html =~ "Generate Bearer tokens for external AI agents"
      
      # The component should be present
      assert has_element?(view, "#mcp-token-manager")
    end

    test "can create and manage tokens", %{conn: conn, author: author} do
      project = create_project_with_author(author)
      
      # Create a token directly using the Auth context
      {:ok, {token, _token_string}} = Auth.create_token(author.id, project.id, "Test token")
      
      # Load the page and verify token appears
      {:ok, view, html} = live(conn, ~p"/workspaces/course_author/#{project.slug}/overview")
      
      # Check that token info is displayed
      assert html =~ "Bearer Token"
      assert html =~ "Test token"
      
      # Update token status
      {:ok, _updated} = Auth.update_token_status(token.id, "disabled")
      
      # Regenerate token
      {:ok, {new_token, _new_string}} = Auth.regenerate_token(author.id, project.id, "New description")
      
      assert new_token.id == token.id
      assert new_token.hint == "New description"
      assert new_token.hash != token.hash
    end

  end

  defp create_project_with_author(author) do
    %{project: project} = base_project_with_curriculum(nil)
    insert(:author_project, project_id: project.id, author_id: author.id)
    project
  end
end