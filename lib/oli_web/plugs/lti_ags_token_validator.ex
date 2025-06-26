defmodule OliWeb.Plugs.LtiAgsTokenValidator do
  import Plug.Conn

  alias Oli.Lti.Tokens

  def init(opts), do: opts

  def call(conn, opts) do
    # Extract the required scope from options
    required_scope = opts[:require_scope]

    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- Tokens.verify_token(token) do
      # Check if the token has the required scope, if specified
      scope = claims["scope"] || []

      if is_nil(required_scope) or required_scope in scope do
        conn
      else
        conn
        |> send_resp(401, "Unauthorized: Missing required scope: #{required_scope}")
        |> halt()
      end
    else
      _ ->
        conn
        |> send_resp(401, "Unauthorized: Missing or invalid access token")
        |> halt()
    end
  end
end
