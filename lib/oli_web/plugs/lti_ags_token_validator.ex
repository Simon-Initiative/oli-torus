defmodule OliWeb.Plugs.LtiAgsTokenValidator do
  import Plug.Conn

  alias Oli.Lti.Tokens

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- Tokens.verify_token(token) do
      assign(conn, :lti_ags_claims, claims)
    else
      _ ->
        conn
        |> send_resp(401, "Unauthorized: Missing or invalid access token")
        |> halt()
    end
  end
end
