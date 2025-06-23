defmodule OliWeb.Plugs.LtiAgsTokenValidator do
  import Plug.Conn

  alias Oli.Lti.Tokens

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

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- Tokens.verify_token(token) do
      assign(conn, :lti_ags_claims, claims)
    else
      _ ->
        conn
        |> send_resp(401, "Unauthorized")
        |> halt()
    end
  end
end
