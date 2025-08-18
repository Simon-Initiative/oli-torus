defmodule Oli.MCP.SecurityTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.MCP.Auth
  alias Oli.MCP.Auth.TokenGenerator

  describe "Token Security Properties" do
    test "tokens are cryptographically secure" do
      # Generate multiple tokens and verify entropy
      tokens =
        for _ <- 1..100 do
          TokenGenerator.generate()
        end

      # All tokens should be unique
      unique_tokens = Enum.uniq(tokens)
      assert length(tokens) == length(unique_tokens)

      # Check token length (should be sufficient for security)
      Enum.each(tokens, fn token ->
        # mcp_ + base64 of 32 bytes
        assert String.length(token) >= 40
      end)

      # Verify tokens contain sufficient entropy (rough check)
      # Count unique characters across all tokens
      all_chars =
        tokens
        |> Enum.join("")
        |> String.graphemes()
        |> Enum.uniq()
        |> length()

      # Should contain a good variety of characters
      assert all_chars >= 20
    end

    test "token hashes are not reversible" do
      token = TokenGenerator.generate()
      hash = TokenGenerator.hash(token)

      # Hash should be different from token
      refute hash == token

      # Hash should not contain the original token
      refute String.contains?(Base.encode64(hash), token)
      refute String.contains?(Base.encode16(hash), token)

      # But should validate correctly
      assert TokenGenerator.matches?(token, hash)
    end

    test "timing attack resistance for token validation" do
      # Create a valid token
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {_token_record, valid_token}} = Auth.create_token(author.id, project.id)

      # Generate invalid tokens of various lengths
      invalid_tokens = [
        "short",
        "mcp_invalid",
        String.duplicate("mcp_", 100),
        # Valid format but wrong token
        TokenGenerator.generate(),
        # Almost valid
        valid_token <> "x",
        # Almost valid (truncated)
        String.slice(valid_token, 0..-2//1)
      ]

      # Measure validation times for invalid tokens
      invalid_times =
        Enum.map(invalid_tokens, fn token ->
          {time, _result} = :timer.tc(fn -> Auth.validate_token(token) end)
          time
        end)

      # Measure validation time for valid token
      {valid_time, _} = :timer.tc(fn -> Auth.validate_token(valid_token) end)

      # All validation times should be within a reasonable range
      # This is a rough check - in practice, timing attacks are complex
      max_time = Enum.max([valid_time | invalid_times])
      min_time = Enum.min([valid_time | invalid_times])

      # The ratio shouldn't be too extreme (allowing for some variance)
      # Only calculate ratio if min_time is not zero
      if min_time > 0 do
        ratio = max_time / min_time
        assert ratio < 100, "Validation times vary too much (possible timing attack vector)"
      end
    end

    test "hash collision resistance" do
      # Generate many tokens and verify no hash collisions
      tokens =
        for _ <- 1..1000 do
          TokenGenerator.generate()
        end

      hashes = Enum.map(tokens, &TokenGenerator.hash/1)
      unique_hashes = Enum.uniq(hashes)

      assert length(hashes) == length(unique_hashes), "Hash collision detected!"
    end

    test "token format prevents injection attacks" do
      # Try various injection patterns that should be rejected by format validation
      malicious_inputs = [
        # SQL injection without prefix
        "'; DROP TABLE mcp_bearer_tokens; --",
        # XSS without prefix  
        "<script>alert('xss')</script>",
        # Too short
        "mcp_short",
        # Wrong prefix
        "wrong_prefix_abcdefghijklmnopqrstuvwxyz",
        # Empty string
        "",
        # Just prefix
        "mcp_"
      ]

      Enum.each(malicious_inputs, fn input ->
        # Should be rejected at format validation level
        refute TokenGenerator.valid_format?(input)

        # Should be rejected by auth system
        assert {:error, :invalid_token_format} = Auth.validate_token(input)
      end)

      # Test that longer valid-format tokens are handled correctly by auth system
      valid_format_but_invalid_tokens = [
        # Valid format but invalid token
        "mcp_#{String.duplicate("A", 40)}",
        # Valid format, invalid token
        "mcp_" <> Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
      ]

      Enum.each(valid_format_but_invalid_tokens, fn input ->
        # Should pass format validation
        assert TokenGenerator.valid_format?(input)

        # But should be rejected by auth system as invalid token
        assert {:error, :invalid_token} = Auth.validate_token(input)
      end)
    end
  end

  describe "Authorization Boundary Enforcement" do
    test "author cannot create token for project they don't have access to" do
      author = insert(:author)
      other_author = insert(:author)
      project = insert(:project)

      # Only other_author has access to project
      _author_project =
        insert(:author_project, author_id: other_author.id, project_id: project.id)

      assert {:error, :unauthorized_project_access} =
               Auth.create_token(author.id, project.id)
    end

    test "token becomes invalid when author loses project access" do
      author = insert(:author)
      project = insert(:project)
      author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      # Create token while author has access
      {:ok, {_token_record, token_string}} = Auth.create_token(author.id, project.id)

      # Verify token works
      assert {:ok, _} = Auth.validate_token(token_string)

      # Remove author's access to project
      Oli.Repo.delete!(author_project)

      # Token should now be invalid
      assert {:error, :unauthorized_project_access} = Auth.validate_token(token_string)
    end

    test "token becomes invalid when project is deleted" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {_token_record, token_string}} = Auth.create_token(author.id, project.id)

      # Verify token works
      assert {:ok, _} = Auth.validate_token(token_string)

      # Delete project
      Oli.Repo.update!(Oli.Authoring.Course.Project.changeset(project, %{status: :deleted}))

      # Token should now be invalid
      assert {:error, :project_deleted} = Auth.validate_token(token_string)
    end

    test "deleting author cascades to delete bearer tokens" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {token_record, token_string}} = Auth.create_token(author.id, project.id)

      # Verify token exists and works
      assert Auth.get_token_by_author_and_project(author.id, project.id) != nil
      assert {:ok, _} = Auth.validate_token(token_string)

      # Delete author (should cascade delete token due to foreign key constraint)
      Oli.Repo.delete!(author)

      # Token should no longer exist
      assert Auth.get_token_by_author_and_project(author.id, project.id) == nil
      assert {:error, :invalid_token} = Auth.validate_token(token_string)

      # Token record should be deleted from database
      refute Oli.Repo.get(Oli.MCP.Auth.BearerToken, token_record.id)
    end

    test "deleting project cascades to delete bearer tokens" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {token_record, token_string}} = Auth.create_token(author.id, project.id)

      # Verify token exists and works
      assert Auth.get_token_by_author_and_project(author.id, project.id) != nil
      assert {:ok, _} = Auth.validate_token(token_string)

      # Delete project (should cascade delete token due to foreign key constraint)
      # First delete the author_project association
      Oli.Repo.delete_all(
        from ap in Oli.Authoring.Authors.AuthorProject, where: ap.project_id == ^project.id
      )

      Oli.Repo.delete!(project)

      # Token should no longer exist
      assert Auth.get_token_by_author_and_project(author.id, project.id) == nil
      assert {:error, :invalid_token} = Auth.validate_token(token_string)

      # Token record should be deleted from database
      refute Oli.Repo.get(Oli.MCP.Auth.BearerToken, token_record.id)
    end

    test "one token per author-project combination enforced by database constraint" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      # Create first token
      assert {:ok, _} = Auth.create_token(author.id, project.id)

      # Attempt to create second token should fail with constraint error
      assert {:error, changeset} = Auth.create_token(author.id, project.id)
      assert %{author_id: ["Author can only have one token per project"]} = errors_on(changeset)
    end
  end

  describe "Token Lifecycle Security" do
    test "regenerated tokens invalidate previous tokens" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      # Create initial token
      {:ok, {_token1, token_string1}} = Auth.create_token(author.id, project.id)

      # Verify it works
      assert {:ok, _} = Auth.validate_token(token_string1)

      # Regenerate token
      {:ok, {_token2, token_string2}} = Auth.regenerate_token(author.id, project.id)

      # Old token should no longer work
      assert {:error, :invalid_token} = Auth.validate_token(token_string1)

      # New token should work
      assert {:ok, _} = Auth.validate_token(token_string2)
    end

    test "disabled tokens cannot be used" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {token_record, token_string}} = Auth.create_token(author.id, project.id)

      # Verify token works initially
      assert {:ok, _} = Auth.validate_token(token_string)

      # Disable token
      Auth.update_token_status(token_record.id, :disabled)

      # Token should no longer work
      assert {:error, :token_disabled} = Auth.validate_token(token_string)
    end

    test "token hints do not reveal sensitive information" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {token_record, token_string}} =
        Auth.create_token(author.id, project.id, "My secret token")

      # Hint should be the description, not contain the actual token
      assert token_record.hint == "My secret token"
      refute String.contains?(token_record.hint, token_string)

      # Auto-generated hints should be safe
      {:ok, {token_record2, token_string2}} = Auth.regenerate_token(author.id, project.id)

      # Auto-generated hint should contain masked version, not full token
      assert String.contains?(token_record2.hint, "****")
      refute String.contains?(token_record2.hint, token_string2)
      assert String.starts_with?(token_record2.hint, "mcp_")
      assert String.ends_with?(token_record2.hint, String.slice(token_string2, -4..-1))
    end
  end

  describe "Database Security" do
    test "raw tokens are never stored in database" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {token_record, token_string}} = Auth.create_token(author.id, project.id)

      # Check that token is not stored in any field
      refute token_record.hash == token_string
      refute token_record.hint == token_string

      # Verify we can't find the token by searching the database
      # This is a simplified check - in practice, you'd want to ensure
      # the token doesn't appear in any database dumps or logs
      query_result =
        Oli.Repo.all(
          from bt in Oli.MCP.Auth.BearerToken,
            where:
              fragment("? = ?", bt.hash, ^token_string) or
                fragment("? = ?", bt.hint, ^token_string)
        )

      assert Enum.empty?(query_result)
    end

    test "hash storage uses appropriate algorithm" do
      token = TokenGenerator.generate()
      hash = TokenGenerator.hash(token)

      # Hash should be exactly 16 bytes (MD5)
      assert byte_size(hash) == 16

      # Hash should be deterministic
      hash2 = TokenGenerator.hash(token)
      assert hash == hash2

      # Different tokens should produce different hashes
      other_token = TokenGenerator.generate()
      other_hash = TokenGenerator.hash(other_token)
      refute hash == other_hash
    end
  end

  describe "Rate Limiting and Abuse Prevention" do
    test "token validation should be reasonably fast" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {_token_record, token_string}} = Auth.create_token(author.id, project.id)

      # Validation should complete quickly (under 100ms)
      {time_microseconds, {:ok, _}} = :timer.tc(fn -> Auth.validate_token(token_string) end)
      time_milliseconds = time_microseconds / 1000

      assert time_milliseconds < 100, "Token validation took #{time_milliseconds}ms (too slow)"
    end

    test "large number of invalid tokens don't cause performance issues" do
      # Generate many invalid tokens
      invalid_tokens =
        for _ <- 1..100 do
          "mcp_" <> Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
        end

      # Measure total time to validate all invalid tokens
      {total_time, _results} =
        :timer.tc(fn ->
          Enum.map(invalid_tokens, &Auth.validate_token/1)
        end)

      # Should complete in reasonable time (under 1 second total)
      total_time_ms = total_time / 1000
      assert total_time_ms < 1000, "Validating 100 invalid tokens took #{total_time_ms}ms"
    end
  end
end
