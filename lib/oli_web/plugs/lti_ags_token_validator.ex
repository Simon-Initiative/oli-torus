defmodule OliWeb.Plugs.LtiAgsTokenValidator do
  import Plug.Conn

  alias Oli.Lti.Tokens

  def init(opts), do: opts

  def call(conn, opts) do
    # Extract the required scope from options
    required_scope =
      opts[:scope] || raise ArgumentError, "Required 'scope' not provided in options"

    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- Tokens.verify_token(token) do
      # Check if the token has the required scope, if specified
      if has_required_scope(claims["scope"], required_scope) do
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

  defp has_required_scope(token_scope, required_scope) do
    scopes = scope_as_list(token_scope)
    required_scopes = scope_as_list(required_scope)

    # Check if all required scopes are present in the token's scopes
    Enum.all?(required_scopes, &(&1 in scopes))
  end

  defp scope_as_list(scope) do
    scope
    |> String.split(" ")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.downcase/1)
    |> Enum.reject(&(&1 == ""))
  end
end
