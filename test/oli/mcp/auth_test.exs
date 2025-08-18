defmodule Oli.MCP.AuthTest do
  use Oli.DataCase

  alias Oli.MCP.Auth
  alias Oli.MCP.Auth.BearerToken
  alias Oli.MCP.Auth.TokenGenerator

  import Oli.Factory

  describe "create_token/3" do
    test "creates a valid bearer token for author and project" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      assert {:ok, {token_record, token_string}} =
               Auth.create_token(author.id, project.id, "Test token")

      assert %BearerToken{} = token_record
      assert token_record.author_id == author.id
      assert token_record.project_id == project.id
      assert token_record.hint == "Test token"
      assert token_record.status == "enabled"
      assert is_binary(token_record.hash)
      assert is_binary(token_string)
      assert String.starts_with?(token_string, "mcp_")
      assert TokenGenerator.valid_format?(token_string)
    end

    test "auto-generates hint when none provided" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      assert {:ok, {token_record, _token_string}} =
               Auth.create_token(author.id, project.id)

      assert token_record.hint != nil
      assert String.starts_with?(token_record.hint, "mcp_")
      assert String.contains?(token_record.hint, "****")
    end

    test "requires author to be a collaborator on the project" do
      author = insert(:author)
      project = insert(:project)
      # Not creating AuthorProject association

      assert {:error, :unauthorized_project_access} =
               Auth.create_token(author.id, project.id, "Test token")
    end

    test "requires project to exist" do
      author = insert(:author)
      non_existent_project_id = 99999

      assert {:error, :unauthorized_project_access} =
               Auth.create_token(author.id, non_existent_project_id, "Test token")
    end

    test "prevents creating tokens for deleted projects" do
      author = insert(:author)
      project = insert(:project, status: :deleted)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      assert {:error, :project_deleted} =
               Auth.create_token(author.id, project.id, "Test token")
    end

    test "prevents duplicate tokens for same author/project combination" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      assert {:ok, _} = Auth.create_token(author.id, project.id)
      assert {:error, changeset} = Auth.create_token(author.id, project.id)

      assert %{author_id: ["Author can only have one token per project"]} = errors_on(changeset)
    end
  end

  describe "validate_token/1" do
    test "validates a correct token" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {_token_record, token_string}} = Auth.create_token(author.id, project.id)

      assert {:ok, %{author_id: author_id, project_id: project_id}} =
               Auth.validate_token(token_string)

      assert author_id == author.id
      assert project_id == project.id
    end

    test "rejects token with invalid format" do
      assert {:error, :invalid_token_format} = Auth.validate_token("invalid_token")
      assert {:error, :invalid_token_format} = Auth.validate_token("mcp_short")
      assert {:error, :invalid_token_format} = Auth.validate_token("wrong_prefix_abcdefghijklmnopqrstuvwxyz")
    end

    test "rejects non-existent token with valid format" do
      fake_token = TokenGenerator.generate()
      assert {:error, :invalid_token} = Auth.validate_token(fake_token)
    end

    test "rejects disabled token" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {token_record, token_string}} = Auth.create_token(author.id, project.id)
      Auth.update_token_status(token_record.id, "disabled")

      assert {:error, :token_disabled} = Auth.validate_token(token_string)
    end

    test "rejects token when project is deleted" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {_token_record, token_string}} = Auth.create_token(author.id, project.id)

      # Delete the project after token creation
      Oli.Repo.update!(Oli.Authoring.Course.Project.changeset(project, %{status: :deleted}))

      assert {:error, :project_deleted} = Auth.validate_token(token_string)
    end

    test "rejects token when author project association is removed" do
      author = insert(:author)
      project = insert(:project)
      author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {_token_record, token_string}} = Auth.create_token(author.id, project.id)

      # Remove the author-project association
      Oli.Repo.delete!(author_project)

      assert {:error, :unauthorized_project_access} = Auth.validate_token(token_string)
    end

    test "rejects token when author is deleted" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {_token_record, token_string}} = Auth.create_token(author.id, project.id)

      # Delete the author (this will cascade delete the bearer token due to foreign key constraint)
      Oli.Repo.delete!(author)

      assert {:error, :invalid_token} = Auth.validate_token(token_string)
    end

    test "updates last_used_at timestamp on successful validation" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {_token_record, token_string}} = Auth.create_token(author.id, project.id)

      # Sleep briefly to ensure timestamp difference
      :timer.sleep(10)

      assert {:ok, _} = Auth.validate_token(token_string)

      updated_token = Auth.get_token_by_author_and_project(author.id, project.id)
      assert updated_token.last_used_at != nil
      # The timestamp should be recent (within the last second)
      assert DateTime.diff(DateTime.utc_now(), updated_token.last_used_at, :millisecond) < 1000
    end
  end

  describe "get_token_by_author_and_project/2" do
    test "retrieves existing token" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {created_token, _}} = Auth.create_token(author.id, project.id)

      retrieved_token = Auth.get_token_by_author_and_project(author.id, project.id)

      assert retrieved_token.id == created_token.id
    end

    test "returns nil when no token exists" do
      author = insert(:author)
      project = insert(:project)

      assert Auth.get_token_by_author_and_project(author.id, project.id) == nil
    end
  end

  describe "regenerate_token/3" do
    test "creates new token when none exists" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      assert {:ok, {token_record, token_string}} =
               Auth.regenerate_token(author.id, project.id, "New token")

      assert token_record.hint == "New token"
      assert String.starts_with?(token_string, "mcp_")
      assert TokenGenerator.valid_format?(token_string)
    end

    test "replaces existing token" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {original_token, original_string}} =
        Auth.create_token(author.id, project.id, "Original")

      {:ok, {new_token, new_string}} = Auth.regenerate_token(author.id, project.id, "Regenerated")

      assert original_token.id == new_token.id
      assert new_token.hint == "Regenerated"
      assert original_string != new_string

      # Original token should no longer be valid
      assert {:error, :invalid_token} = Auth.validate_token(original_string)

      # New token should be valid
      assert {:ok, _} = Auth.validate_token(new_string)
    end

    test "requires author to be a collaborator for regeneration" do
      author = insert(:author)
      project = insert(:project)
      # Not creating AuthorProject association

      assert {:error, :unauthorized_project_access} =
               Auth.regenerate_token(author.id, project.id, "Should fail")
    end

    test "auto-generates hint when regenerating without hint" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      assert {:ok, {token_record, _token_string}} =
               Auth.regenerate_token(author.id, project.id)

      assert token_record.hint != nil
      assert String.starts_with?(token_record.hint, "mcp_")
      assert String.contains?(token_record.hint, "****")
    end
  end

  describe "verify_author_can_manage_token/2" do
    test "allows token management for project collaborators" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      assert :ok = Auth.verify_author_can_manage_token(author.id, project.id)
    end

    test "denies token management for non-collaborators" do
      author = insert(:author)
      project = insert(:project)
      # Not creating AuthorProject association

      assert {:error, :unauthorized_project_access} =
               Auth.verify_author_can_manage_token(author.id, project.id)
    end

    test "denies token management for deleted projects" do
      author = insert(:author)
      project = insert(:project, status: :deleted)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      assert {:error, :project_deleted} =
               Auth.verify_author_can_manage_token(author.id, project.id)
    end
  end

  describe "security properties" do
    test "tokens are cryptographically unique" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      # Generate multiple tokens by regenerating
      tokens = 
        for _ <- 1..10 do
          {:ok, {_token_record, token_string}} = Auth.regenerate_token(author.id, project.id)
          token_string
        end

      # All tokens should be unique
      unique_tokens = Enum.uniq(tokens)
      assert length(tokens) == length(unique_tokens)

      # All tokens should have valid format
      assert Enum.all?(tokens, &TokenGenerator.valid_format?/1)
    end

    test "token hashes are not reversible" do
      author = insert(:author)
      project = insert(:project)
      _author_project = insert(:author_project, author_id: author.id, project_id: project.id)

      {:ok, {token_record, token_string}} = Auth.create_token(author.id, project.id)

      # The stored hash should not reveal the original token
      refute token_record.hash == token_string
      refute String.contains?(Base.encode64(token_record.hash), token_string)

      # But it should validate correctly
      assert TokenGenerator.matches?(token_string, token_record.hash)
    end
  end
end
