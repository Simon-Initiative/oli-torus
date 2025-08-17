defmodule Oli.MCP.AuthTest do
  use Oli.DataCase

  alias Oli.MCP.Auth
  alias Oli.MCP.Auth.BearerToken

  import Oli.Factory

  describe "create_token/3" do
    test "creates a valid bearer token for author and project" do
      author = insert(:author)
      project = insert(:project)

      assert {:ok, {token_record, token_string}} = Auth.create_token(author.id, project.id, "Test token")

      assert %BearerToken{} = token_record
      assert token_record.author_id == author.id
      assert token_record.project_id == project.id
      assert token_record.hint == "Test token"
      assert token_record.status == "enabled"
      assert is_binary(token_record.hash)
      assert is_binary(token_string)
      assert String.starts_with?(token_string, "mcp_")
    end

    test "prevents duplicate tokens for same author/project combination" do
      author = insert(:author)
      project = insert(:project)

      assert {:ok, _} = Auth.create_token(author.id, project.id)
      assert {:error, changeset} = Auth.create_token(author.id, project.id)

      assert %{author_id: ["Author can only have one token per project"]} = errors_on(changeset)
    end
  end

  describe "validate_token/1" do
    test "validates a correct token" do
      author = insert(:author)
      project = insert(:project)

      {:ok, {_token_record, token_string}} = Auth.create_token(author.id, project.id)

      assert {:ok, %{author_id: author_id, project_id: project_id}} = Auth.validate_token(token_string)
      assert author_id == author.id
      assert project_id == project.id
    end

    test "rejects invalid token" do
      assert {:error, :invalid_token} = Auth.validate_token("invalid_token")
    end

    test "rejects disabled token" do
      author = insert(:author)
      project = insert(:project)

      {:ok, {token_record, token_string}} = Auth.create_token(author.id, project.id)
      Auth.update_token_status(token_record.id, "disabled")

      assert {:error, :token_disabled} = Auth.validate_token(token_string)
    end
  end

  describe "get_token_by_author_and_project/2" do
    test "retrieves existing token" do
      author = insert(:author)
      project = insert(:project)

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

      assert {:ok, {token_record, token_string}} = Auth.regenerate_token(author.id, project.id, "New token")

      assert token_record.hint == "New token"
      assert String.starts_with?(token_string, "mcp_")
    end

    test "replaces existing token" do
      author = insert(:author)
      project = insert(:project)

      {:ok, {original_token, original_string}} = Auth.create_token(author.id, project.id, "Original")
      {:ok, {new_token, new_string}} = Auth.regenerate_token(author.id, project.id, "Regenerated")

      assert original_token.id == new_token.id
      assert new_token.hint == "Regenerated"
      assert original_string != new_string

      # Original token should no longer be valid
      assert {:error, :invalid_token} = Auth.validate_token(original_string)

      # New token should be valid
      assert {:ok, _} = Auth.validate_token(new_string)
    end
  end
end