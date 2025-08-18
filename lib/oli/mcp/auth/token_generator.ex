defmodule Oli.MCP.Auth.TokenGenerator do
  @moduledoc """
  Cryptographically secure token generation for MCP Bearer authentication.
  
  This module handles the generation and hashing of Bearer tokens used for
  authenticating external AI agents to the MCP server. Tokens are generated
  with strong randomness and follow a consistent format for easy identification.
  
  ## Token Format
  
  Tokens have the format: `mcp_<base64_encoded_random_bytes>`
  
  - Prefix: "mcp_" for easy identification
  - Body: 32 bytes of cryptographically secure random data, base64 encoded
  - Total length: Approximately 47 characters
  
  ## Security Considerations
  
  - Tokens are generated using :crypto.strong_rand_bytes/1 for cryptographic security
  - Only MD5 hashes of tokens are stored in the database (following existing pattern)
  - Tokens cannot be recovered from their hashes
  - Each token provides access to exactly one project for one author
  """

  @token_prefix "mcp_"
  @token_bytes 32
  @hash_algorithm :md5

  @doc """
  Generates a new cryptographically secure Bearer token.
  
  Returns a string token with the format: "mcp_<base64_encoded_random>"
  
  ## Examples
  
      iex> token = Oli.MCP.Auth.TokenGenerator.generate()
      iex> String.starts_with?(token, "mcp_")
      true
      iex> String.length(token) > 40
      true
  """
  @spec generate() :: String.t()
  def generate do
    random_bytes = :crypto.strong_rand_bytes(@token_bytes)
    @token_prefix <> Base.url_encode64(random_bytes, padding: false)
  end

  @doc """
  Generates a secure hash of a token for storage.
  
  Uses MD5 hashing to match the existing API key pattern in the codebase.
  Returns the hash as a binary suitable for database storage.
  
  ## Parameters
  
  - `token` - The plain text Bearer token to hash
  
  ## Examples
  
      iex> token = "mcp_test_token"
      iex> hash = Oli.MCP.Auth.TokenGenerator.hash(token)
      iex> is_binary(hash)
      true
      iex> byte_size(hash)
      16
  """
  @spec hash(String.t()) :: binary()
  def hash(token) when is_binary(token) do
    :crypto.hash(@hash_algorithm, token)
  end

  @doc """
  Validates that a token matches the expected format.
  
  Returns true if the token has the correct prefix and reasonable length,
  false otherwise. This is a format check only, not an authentication check.
  
  ## Parameters
  
  - `token` - The token string to validate
  
  ## Examples
  
      iex> Oli.MCP.Auth.TokenGenerator.valid_format?("mcp_abcdef123456")
      true
      iex> Oli.MCP.Auth.TokenGenerator.valid_format?("invalid_token")
      false
      iex> Oli.MCP.Auth.TokenGenerator.valid_format?(nil)
      false
  """
  @spec valid_format?(any()) :: boolean()
  def valid_format?(token) when is_binary(token) do
    String.starts_with?(token, @token_prefix) && String.length(token) >= 40
  end

  def valid_format?(_), do: false

  @doc """
  Generates a hint from a token for display purposes.
  
  Shows the prefix and last 4 characters of the token with asterisks in between.
  This allows users to identify tokens without exposing the full value.
  
  ## Parameters
  
  - `token` - The full token to create a hint from
  
  ## Examples
  
      iex> Oli.MCP.Auth.TokenGenerator.create_hint("mcp_abcdefghijklmnopqrstuvwxyz1234")
      "mcp_****1234"
      iex> Oli.MCP.Auth.TokenGenerator.create_hint("short")
      "****"
  """
  @spec create_hint(String.t()) :: String.t()
  def create_hint(token) when is_binary(token) do
    if String.length(token) > 8 do
      prefix = String.slice(token, 0, 4)
      suffix = String.slice(token, -4, 4)
      prefix <> "****" <> suffix
    else
      "****"
    end
  end

  @doc """
  Compares a token with a hash to check if they match.
  
  This is a convenience function that hashes the token and compares
  it with the provided hash using constant-time comparison.
  
  ## Parameters
  
  - `token` - The plain text token
  - `hash` - The stored hash to compare against
  
  ## Examples
  
      iex> token = "mcp_test"
      iex> hash = Oli.MCP.Auth.TokenGenerator.hash(token)
      iex> Oli.MCP.Auth.TokenGenerator.matches?(token, hash)
      true
      iex> Oli.MCP.Auth.TokenGenerator.matches?("wrong_token", hash)
      false
  """
  @spec matches?(String.t(), binary()) :: boolean()
  def matches?(token, hash) when is_binary(token) and is_binary(hash) do
    token_hash = hash(token)
    secure_compare(token_hash, hash)
  end

  def matches?(_, _), do: false

  # Constant-time comparison to prevent timing attacks
  defp secure_compare(a, b) when byte_size(a) == byte_size(b) do
    a_list = :binary.bin_to_list(a)
    b_list = :binary.bin_to_list(b)

    result =
      Enum.zip(a_list, b_list)
      |> Enum.reduce(0, fn {x, y}, acc ->
        Bitwise.bor(acc, Bitwise.bxor(x, y))
      end)

    result == 0
  end

  defp secure_compare(_, _), do: false
end