defmodule Oli.MCP.Auth.TokenGeneratorTest do
  use ExUnit.Case, async: true

  alias Oli.MCP.Auth.TokenGenerator

  describe "generate/0" do
    test "generates tokens with correct prefix" do
      token = TokenGenerator.generate()
      assert String.starts_with?(token, "mcp_")
    end

    test "generates tokens with reasonable length" do
      token = TokenGenerator.generate()
      # Should be at least 40 characters (mcp_ + base64 of 32 bytes)
      assert String.length(token) >= 40
    end

    test "generates unique tokens" do
      token1 = TokenGenerator.generate()
      token2 = TokenGenerator.generate()
      token3 = TokenGenerator.generate()

      assert token1 != token2
      assert token2 != token3
      assert token1 != token3
    end

    test "generates tokens with valid base64 after prefix" do
      token = TokenGenerator.generate()
      "mcp_" <> encoded = token

      # Should be valid base64 (will raise if invalid)
      assert {:ok, _decoded} = Base.url_decode64(encoded, padding: false)
    end
  end

  describe "hash/1" do
    test "generates consistent hash for same token" do
      token = "mcp_test_token"
      hash1 = TokenGenerator.hash(token)
      hash2 = TokenGenerator.hash(token)

      assert hash1 == hash2
    end

    test "generates different hashes for different tokens" do
      hash1 = TokenGenerator.hash("mcp_token1")
      hash2 = TokenGenerator.hash("mcp_token2")

      assert hash1 != hash2
    end

    test "returns binary hash" do
      hash = TokenGenerator.hash("mcp_test")

      assert is_binary(hash)
      # MD5 is 16 bytes
      assert byte_size(hash) == 16
    end
  end

  describe "valid_format?/1" do
    test "returns true for valid token format" do
      token = TokenGenerator.generate()
      assert TokenGenerator.valid_format?(token)
    end

    test "returns true for tokens with mcp_ prefix and sufficient length" do
      assert TokenGenerator.valid_format?("mcp_abcdefghijklmnopqrstuvwxyz1234567890")
    end

    test "returns false for tokens without mcp_ prefix" do
      refute TokenGenerator.valid_format?("invalid_token_without_prefix")
    end

    test "returns false for tokens that are too short" do
      refute TokenGenerator.valid_format?("mcp_short")
    end

    test "returns false for nil" do
      refute TokenGenerator.valid_format?(nil)
    end

    test "returns false for non-string values" do
      refute TokenGenerator.valid_format?(123)
      refute TokenGenerator.valid_format?(%{})
      refute TokenGenerator.valid_format?([])
    end
  end

  describe "create_hint/1" do
    test "creates hint with prefix and suffix for long tokens" do
      token = "mcp_abcdefghijklmnopqrstuvwxyz1234"
      hint = TokenGenerator.create_hint(token)

      assert hint == "mcp_****1234"
    end

    test "handles short tokens gracefully" do
      hint = TokenGenerator.create_hint("short")
      assert hint == "****"
    end

    test "creates different hints for different tokens" do
      token1 = "mcp_abcdefghijklmnopqrstuvwxyz1111"
      token2 = "mcp_abcdefghijklmnopqrstuvwxyz2222"

      hint1 = TokenGenerator.create_hint(token1)
      hint2 = TokenGenerator.create_hint(token2)

      assert hint1 != hint2
      assert hint1 == "mcp_****1111"
      assert hint2 == "mcp_****2222"
    end

    test "works with generated tokens" do
      token = TokenGenerator.generate()
      hint = TokenGenerator.create_hint(token)

      assert String.starts_with?(hint, "mcp_")
      assert String.contains?(hint, "****")
      # "mcp_****XXXX"
      assert String.length(hint) == 12
    end
  end

  describe "matches?/2" do
    test "returns true when token matches hash" do
      token = "mcp_test_token"
      hash = TokenGenerator.hash(token)

      assert TokenGenerator.matches?(token, hash)
    end

    test "returns false when token doesn't match hash" do
      token = "mcp_test_token"
      wrong_token = "mcp_wrong_token"
      hash = TokenGenerator.hash(token)

      refute TokenGenerator.matches?(wrong_token, hash)
    end

    test "returns false for invalid inputs" do
      hash = TokenGenerator.hash("test")

      refute TokenGenerator.matches?(nil, hash)
      refute TokenGenerator.matches?("test", nil)
      refute TokenGenerator.matches?(123, hash)
    end

    test "handles binary differences correctly" do
      # Create two tokens that might have similar but different hashes
      token1 = "mcp_test_token_1"
      token2 = "mcp_test_token_2"

      hash1 = TokenGenerator.hash(token1)
      hash2 = TokenGenerator.hash(token2)

      assert TokenGenerator.matches?(token1, hash1)
      assert TokenGenerator.matches?(token2, hash2)
      refute TokenGenerator.matches?(token1, hash2)
      refute TokenGenerator.matches?(token2, hash1)
    end
  end

  describe "integration tests" do
    test "complete token lifecycle" do
      # Generate a token
      token = TokenGenerator.generate()

      # Verify format
      assert TokenGenerator.valid_format?(token)

      # Hash it
      hash = TokenGenerator.hash(token)

      # Verify it matches
      assert TokenGenerator.matches?(token, hash)

      # Create hint
      hint = TokenGenerator.create_hint(token)
      assert String.contains?(hint, "****")

      # Verify different token doesn't match
      other_token = TokenGenerator.generate()
      refute TokenGenerator.matches?(other_token, hash)
    end

    test "security properties" do
      # Generate multiple tokens and verify they're all unique
      tokens = Enum.map(1..100, fn _ -> TokenGenerator.generate() end)
      unique_tokens = Enum.uniq(tokens)

      assert length(tokens) == length(unique_tokens), "All generated tokens should be unique"

      # Verify all tokens have valid format
      assert Enum.all?(tokens, &TokenGenerator.valid_format?/1)

      # Verify hashes are different for different tokens
      hashes = Enum.map(tokens, &TokenGenerator.hash/1)
      unique_hashes = Enum.uniq(hashes)

      assert length(hashes) == length(unique_hashes), "All hashes should be unique"
    end
  end
end
