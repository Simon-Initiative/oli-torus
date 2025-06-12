defmodule OliWeb.Plugs.LtiAgsTokenValidator do
  import Plug.Conn
  require Logger

  # def init(opts), do: opts

  # def call(conn, _opts) do
  #   # Extract Bearer token from Authorization header
  #   case get_req_header(conn, "authorization") do
  #     ["Bearer " <> token] ->
  #       # TODO: Validate the JWT access token (should match what /lti/auth/token issues)
  #       # If valid, assign claims to conn; if not, halt with 401
  #       # For now, just allow all requests (placeholder)
  #       conn

  #     _ ->
  #       conn
  #       |> send_resp(401, "Unauthorized: Missing or invalid access token")
  #       |> halt()
  #   end
  # end

  def init(opts), do: opts

  def call(conn, opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- verify_token(token, opts) do
      assign(conn, :lti_ags_claims, claims)
    else
      _ ->
        conn
        |> send_resp(401, "Unauthorized")
        |> halt()
    end
  end

  defp verify_token(token, _opts) do
    # Use the same logic as issue_access_token in LtiController
    # Only accept tokens signed by our platform, not by external platforms
    with {:ok, %{pem: pem, alg: _alg, kid: _kid}} <- Lti_1p3.get_active_jwk(),
         jwk <- JOSE.JWK.from_pem(pem),
         {true, jwt, _jws} <- JOSE.JWT.verify(jwk, token),
         %{"exp" => exp, "scope" => _scope} = claims <- jwt.fields,
         true <- DateTime.to_unix(DateTime.utc_now()) < exp do
      # TODO validate claims and scopes
      {:ok, claims}
    else
      e ->
        Logger.error("LTI AGS token validation failed: #{inspect(e)}")
        {:error, :invalid_token}
    end
  end
end
