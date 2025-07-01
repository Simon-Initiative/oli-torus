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
end
