defmodule Oli.MCP.AuthIntegrationTest do
  use OliWeb.ConnCase, async: true

  import Oli.Factory

  alias Oli.MCP.Auth
  alias Oli.MCP.Server

  describe "MCP Authentication Integration" do
    test "complete authentication flow with valid token" do
      # Setup: Create author, project, and token
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {_token_record, token_string}} = Auth.create_token(author.id, project.id, "Integration test token")

      # Test: Simulate MCP Server init with valid Bearer token
      frame = %{transport: %{req_headers: [{"authorization", "Bearer #{token_string}"}]}}
      
      # Assert: Server init should succeed with auth context
      assert {:ok, updated_frame} = Server.init(nil, frame)
      assert updated_frame.assigns.author_id == author.id
      assert updated_frame.assigns.project_id == project.id
      assert updated_frame.assigns.bearer_token == token_string
    end

    test "authentication fails with invalid token" do
      # Test: Simulate MCP Server init with invalid Bearer token
      frame = %{transport: %{req_headers: [{"authorization", "Bearer invalid_token_format"}]}}
      
      # Assert: Server init should stop with unauthorized
      assert {:stop, :unauthorized} = Server.init(nil, frame)
    end

    test "authentication fails with disabled token" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {token_record, token_string}} = Auth.create_token(author.id, project.id)
      Auth.update_token_status(token_record.id, "disabled")

      # Test: Simulate MCP Server init with disabled token
      frame = %{transport: %{req_headers: [{"authorization", "Bearer #{token_string}"}]}}
      
      # Assert: Server init should stop with unauthorized
      assert {:stop, :unauthorized} = Server.init(nil, frame)
    end

    test "authentication fails when project is deleted after token creation" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {_token_record, token_string}} = Auth.create_token(author.id, project.id)

      # Delete the project
      Oli.Repo.update!(Oli.Authoring.Course.Project.changeset(project, %{status: :deleted}))

      # Test: Simulate MCP Server init with token for deleted project
      frame = %{transport: %{req_headers: [{"authorization", "Bearer #{token_string}"}]}}
      
      # Assert: Server init should stop with unauthorized
      assert {:stop, :unauthorized} = Server.init(nil, frame)
    end

    test "authentication fails when author loses project access" do
      author = insert(:author)
      project = insert(:project)
      author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {_token_record, token_string}} = Auth.create_token(author.id, project.id)

      # Remove author from project
      Oli.Repo.delete!(author_project)

      # Test: Simulate MCP Server init with token after access revoked
      frame = %{transport: %{req_headers: [{"authorization", "Bearer #{token_string}"}]}}
      
      # Assert: Server init should stop with unauthorized
      assert {:stop, :unauthorized} = Server.init(nil, frame)
    end

    test "token usage updates last_used_at timestamp" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {token_record, token_string}} = Auth.create_token(author.id, project.id)
      
      # Verify initial state
      assert token_record.last_used_at == nil

      # Use the token through MCP Server init
      frame = %{transport: %{req_headers: [{"authorization", "Bearer #{token_string}"}]}}
      assert {:ok, _updated_frame} = Server.init(nil, frame)

      # Verify timestamp was updated
      updated_token = Auth.get_token_by_author_and_project(author.id, project.id)
      assert updated_token.last_used_at != nil
      assert DateTime.diff(DateTime.utc_now(), updated_token.last_used_at, :millisecond) < 1000
    end

    test "concurrent token validation" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {_token_record, token_string}} = Auth.create_token(author.id, project.id)

      # Simulate concurrent requests
      tasks = 
        for _i <- 1..10 do
          Task.async(fn ->
            frame = %{transport: %{req_headers: [{"authorization", "Bearer #{token_string}"}]}}
            Server.init(nil, frame)
          end)
        end

      results = Task.await_many(tasks, 5000)

      # All requests should succeed
      Enum.each(results, fn result ->
        assert {:ok, frame} = result
        assert frame.assigns.author_id == author.id
        assert frame.assigns.project_id == project.id
      end)
    end

    test "malformed authorization headers" do
      test_cases = [
        {"missing Bearer prefix", "Basic sometoken"},
        {"empty authorization", ""},
        {"just Bearer", "Bearer"},
        {"Bearer with space only", "Bearer "},
        {"wrong case", "bearer mcp_token"},
        {"multiple Bearer tokens", "Bearer token1 Bearer token2"}
      ]

      for {description, auth_header} <- test_cases do
        frame = %{transport: %{req_headers: [{"authorization", auth_header}]}}
        assert {:stop, :unauthorized} = Server.init(nil, frame), "Should fail for: #{description}"
      end
    end

    test "token format validation edge cases" do
      test_cases = [
        {"too short", "mcp_abc"},
        {"wrong prefix", "wrong_prefix_abcdefghijklmnopqrstuvwxyz"},
        {"no prefix", "abcdefghijklmnopqrstuvwxyz123456"},
        {"empty string", ""},
        {"only prefix", "mcp_"},
        {"special characters", "mcp_token@#$%^&*()"},
        {"unicode characters", "mcp_token_ñ_ü_é"},
        {"very long", String.duplicate("mcp_", 1000) <> String.duplicate("a", 1000)}
      ]

      for {description, token} <- test_cases do
        frame = %{transport: %{req_headers: [{"authorization", "Bearer #{token}"}]}}
        assert {:stop, :unauthorized} = Server.init(nil, frame), "Should fail for: #{description}"
      end
    end
  end

  describe "Project Access Authorization" do
    test "token grants access only to specific project" do
      author = insert(:author)
      project1 = insert(:project)
      project2 = insert(:project)
      
      # Author has access to both projects
      _author_project1 = insert(:author_project, author_id: author.id, project_id: project1.id)
      _author_project2 = insert(:author_project, author_id: author.id, project_id: project2.id)

      # Create token for project1
      {:ok, {_token_record, token_string}} = Auth.create_token(author.id, project1.id)

      # Validate token through MCP Server init
      frame = %{transport: %{req_headers: [{"authorization", "Bearer #{token_string}"}]}}
      assert {:ok, updated_frame} = Server.init(nil, frame)
      
      assert updated_frame.assigns.project_id == project1.id
      # Token should NOT grant access to project2
      refute updated_frame.assigns.project_id == project2.id
    end

    test "multiple authors can have tokens for same project" do
      author1 = insert(:author)
      author2 = insert(:author)
      project = insert(:project)
      
      _author_project1 = insert(:author_project, author_id: author1.id, project_id: project.id)
      _author_project2 = insert(:author_project, author_id: author2.id, project_id: project.id)

      # Both authors create tokens for the same project
      {:ok, {_token1, token_string1}} = Auth.create_token(author1.id, project.id)
      {:ok, {_token2, token_string2}} = Auth.create_token(author2.id, project.id)

      # Both tokens should be valid
      frame1 = %{transport: %{req_headers: [{"authorization", "Bearer #{token_string1}"}]}}
      frame2 = %{transport: %{req_headers: [{"authorization", "Bearer #{token_string2}"}]}}
      
      assert {:ok, updated_frame1} = Server.init(nil, frame1)
      assert {:ok, updated_frame2} = Server.init(nil, frame2)
      
      assert updated_frame1.assigns.author_id == author1.id
      assert updated_frame2.assigns.author_id == author2.id
      assert updated_frame1.assigns.project_id == project.id
      assert updated_frame2.assigns.project_id == project.id
    end
  end

  describe "Error Response Format" do
    test "returns unauthorized for invalid token" do
      frame = %{transport: %{req_headers: [{"authorization", "Bearer invalid_token"}]}}
      assert {:stop, :unauthorized} = Server.init(nil, frame)
    end

    test "returns unauthorized for missing authorization header" do
      frame = %{transport: %{req_headers: []}}
      assert {:stop, :unauthorized} = Server.init(nil, frame)
    end
  end
end