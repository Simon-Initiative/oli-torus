defmodule Oli.Lti.Tokens do
  @moduledoc """
  This module provides functionality for LTI 1.3 tokens.
  """

  @doc """
  Issues an LTI AGS access token for a given client ID and scope.
  The token is signed with the active JWK and includes standard claims.
  """

  require Logger

  def issue_access_token(client_id, scope) do
    # Set token expiration (e.g., 1 hour)
    expires_in = 3600
    now = DateTime.utc_now() |> DateTime.to_unix()

    claims = %{
      "sub" => client_id,
      "scope" => scope,
      "iat" => now,
      "exp" => now + expires_in,
      "iss" => Oli.Utils.get_base_url(),
      "aud" => client_id
    }

    # Get the active JWK for signing
    {:ok, jwk} = Lti_1p3.get_active_jwk()

    jwt =
      JOSE.JWT.sign(
        JOSE.JWK.from_pem(jwk.pem),
        %{"alg" => jwk.alg, "kid" => jwk.kid},
        claims
      )
      |> JOSE.JWS.compact()
      |> elem(1)

    {:ok, jwt, expires_in}
  end

  @doc """
  Verifies an LTI AGS token and returns the claims if valid.
  """
  def verify_token(token) do
    with {:ok, %{pem: pem, alg: _alg, kid: _kid}} <- Lti_1p3.get_active_jwk(),
         jwk <- JOSE.JWK.from_pem(pem),
         {true, jwt, _jws} <- JOSE.JWT.verify(jwk, token),
         %{"exp" => exp, "scope" => _scope} = claims <- jwt.fields,
         true <- DateTime.to_unix(DateTime.utc_now()) < exp do
      {:ok, claims}
    else
      e ->
        Logger.error("LTI AGS token validation failed: #{inspect(e)}")

        {:error, :invalid_token}
    end
  end

  def peek_jwt(token) do
    try do
      jwt = JOSE.JWT.peek(token)

      {:ok, jwt}
    rescue
      _ ->
        {:error, :invalid_jwt}
    end
  end

  def get_jwk_for_assertion(keyset_url, kid) do
    keys =
      fetch_public_keyset(keyset_url)
      |> Map.get("keys", [])

    cond do
      is_nil(kid) ->
        # If no kid is provided, assume the first key in the set is the active one
        Logger.warning(
          "No 'kid' provided in client_assertion, using first key in keyset from #{keyset_url}"
        )

        case keys do
          [] ->
            {:error, :no_keys_available}

          [first_key | _] ->
            {:ok, JOSE.JWK.from_map(first_key)}
        end

      true ->
        case Enum.find(keys, fn key -> key["kid"] == kid end) do
          nil -> {:error, :key_not_found}
          key -> {:ok, JOSE.JWK.from_map(key)}
        end
    end
  end

  defp fetch_public_keyset(keyset_url) do
    case Oli.HTTP.http().get(keyset_url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Jason.decode!(body)

      error ->
        error
    end
  end
end
