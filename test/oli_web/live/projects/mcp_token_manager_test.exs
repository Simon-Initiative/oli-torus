defmodule OliWeb.Projects.MCPTokenManagerTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "MCP Token Manager" do
    setup [:author_conn]

    test "displays MCP section on overview page", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      # Enable the MCP authoring feature flag
      {:ok, _} =
        Oli.ScopedFeatureFlags.Audited.enable_feature(
          Oli.Auditing.Context.for_actor(author, source: :ui),
          :mcp_authoring,
          project
        )

      {:ok, view, html} = live(conn, ~p"/workspaces/course_author/#{project.slug}/overview")

      # Check that the MCP section exists
      assert html =~ "MCP Access Tokens"
      assert html =~ "Generate Bearer tokens for external AI agents"

      # The component should be present
      assert has_element?(view, "#mcp-token-manager")
    end

    test "can create and manage tokens", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      # Enable the MCP authoring feature flag
      {:ok, _} =
        Oli.ScopedFeatureFlags.Audited.enable_feature(
          Oli.Auditing.Context.for_actor(author, source: :ui),
          :mcp_authoring,
          project
        )

      # Create a token directly using the Auth context
      {:ok, {token, _token_string}} =
        Oli.MCP.Audited.create_token(
          Oli.TestHelpers.audit_context(),
          author.id,
          project.id,
          "Test token"
        )

      # Load the page and verify token appears
      {:ok, _view, html} = live(conn, ~p"/workspaces/course_author/#{project.slug}/overview")

      # Check that token info is displayed
      assert html =~ "Bearer Token"
      assert html =~ "Test token"

      # Update token status to disabled
      {:ok, _updated} =
        Oli.MCP.Audited.set_token_status(Oli.TestHelpers.audit_context(), token.id, :disabled)

      # Attempt to regenerate disabled token should fail
      assert {:error, :token_disabled} =
               Oli.MCP.Audited.regenerate_token(
                 Oli.TestHelpers.audit_context(),
                 author.id,
                 project.id,
                 "New description"
               )
    end
  end

  defp create_project_with_author(author) do
    # Use Course.create_project to ensure proper publication and root container setup
    {:ok, %{project: project}} = Oli.Authoring.Course.create_project("Test Project", author)
    project
  end
end
