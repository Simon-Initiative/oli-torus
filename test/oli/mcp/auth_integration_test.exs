defmodule Oli.MCP.AuthIntegrationTest do
  use OliWeb.ConnCase, async: true

  import Oli.Factory

  alias Oli.MCP.Auth
  alias OliWeb.Plugs.ValidateMCPBearerToken

  describe "MCP Authentication Integration" do
    test "complete authentication flow with valid token" do
      # Setup: Create author, project, and token
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {_token_record, token_string}} = Auth.create_token(author.id, project.id, "Integration test token")

      # Test: Make request with valid Bearer token
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token_string}")
        |> ValidateMCPBearerToken.call(nil)

      # Assert: Connection should not be halted and should have auth assigns
      refute conn.halted
      assert conn.assigns[:mcp_authenticated] == true
      assert conn.assigns[:mcp_author_id] == author.id
      assert conn.assigns[:mcp_project_id] == project.id
    end

    test "authentication fails with invalid token" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer invalid_token_format")
        |> ValidateMCPBearerToken.call(nil)

      assert conn.halted
      assert conn.status == 401
      assert conn.resp_body == "Invalid MCP Bearer token"
    end

    test "authentication fails with disabled token" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {token_record, token_string}} = Auth.create_token(author.id, project.id)
      Auth.update_token_status(token_record.id, "disabled")

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token_string}")
        |> ValidateMCPBearerToken.call(nil)

      assert conn.halted
      assert conn.status == 401
    end

    test "authentication fails when project is deleted after token creation" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {_token_record, token_string}} = Auth.create_token(author.id, project.id)

      # Delete the project
      Oli.Repo.update!(Oli.Authoring.Course.Project.changeset(project, %{status: :deleted}))

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token_string}")
        |> ValidateMCPBearerToken.call(nil)

      assert conn.halted
      assert conn.status == 401
    end

    test "authentication fails when author loses project access" do
      author = insert(:author)
      project = insert(:project)
      author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {_token_record, token_string}} = Auth.create_token(author.id, project.id)

      # Remove author from project
      Oli.Repo.delete!(author_project)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token_string}")
        |> ValidateMCPBearerToken.call(nil)

      assert conn.halted
      assert conn.status == 401
    end

    test "token usage updates last_used_at timestamp" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {token_record, token_string}} = Auth.create_token(author.id, project.id)
      
      # Verify initial state
      assert token_record.last_used_at == nil

      # Use the token
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token_string}")
        |> ValidateMCPBearerToken.call(nil)

      refute conn.halted

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
            conn =
              build_conn()
              |> put_req_header("authorization", "Bearer #{token_string}")
              |> ValidateMCPBearerToken.call(nil)

            {conn.halted, conn.assigns[:mcp_authenticated]}
          end)
        end

      results = Task.await_many(tasks, 5000)

      # All requests should succeed
      Enum.each(results, fn {halted, authenticated} ->
        refute halted
        assert authenticated == true
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
        conn =
          build_conn()
          |> put_req_header("authorization", auth_header)
          |> ValidateMCPBearerToken.call(nil)

        assert conn.halted, "Should fail for: #{description}"
        assert conn.status == 401, "Should return 401 for: #{description}"
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
        conn =
          build_conn()
          |> put_req_header("authorization", "Bearer #{token}")
          |> ValidateMCPBearerToken.call(nil)

        assert conn.halted, "Should fail for: #{description}"
        assert conn.status == 401, "Should return 401 for: #{description}"
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

      # Validate token
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token_string}")
        |> ValidateMCPBearerToken.call(nil)

      refute conn.halted
      assert conn.assigns[:mcp_project_id] == project1.id
      # Token should NOT grant access to project2
      refute conn.assigns[:mcp_project_id] == project2.id
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
      conn1 =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token_string1}")
        |> ValidateMCPBearerToken.call(nil)

      conn2 =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token_string2}")
        |> ValidateMCPBearerToken.call(nil)

      refute conn1.halted
      refute conn2.halted
      assert conn1.assigns[:mcp_author_id] == author1.id
      assert conn2.assigns[:mcp_author_id] == author2.id
      assert conn1.assigns[:mcp_project_id] == project.id
      assert conn2.assigns[:mcp_project_id] == project.id
    end
  end

  describe "Error Response Format" do
    test "returns error message for invalid token" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer invalid_token")
        |> ValidateMCPBearerToken.call(nil)

      assert conn.halted
      assert conn.status == 401
      assert conn.resp_body == "Invalid MCP Bearer token"
    end

    test "returns error message for missing authorization header" do
      conn = 
        build_conn()
        |> ValidateMCPBearerToken.call(nil)

      assert conn.halted
      assert conn.status == 401
      assert conn.resp_body == "Missing or invalid Authorization header"
    end
  end
end