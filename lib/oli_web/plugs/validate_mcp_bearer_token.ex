defmodule OliWeb.Plugs.ValidateMCPBearerToken do
  @moduledoc """
  Plug to validate MCP Bearer tokens and set authentication context.

  This plug extracts the Bearer token from the Authorization header,
  validates it against the MCP bearer tokens table, and sets the
  authentication context in conn assigns.

  On successful authentication, sets:
  - mcp_authenticated: true
  - mcp_author_id: author_id from token
  - mcp_project_id: project_id from token
  - mcp_token_hash: hash for tracking last_used

  On failed authentication, returns 401 Unauthorized.
  """

  import Plug.Conn
  alias Oli.MCP.Auth

  def init(_opts), do: nil

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        case Auth.validate_token(token) do
          {:ok, %{author_id: author_id, project_id: project_id}} ->
            # Store token in process context for MCP tools to access
            Process.put(:mcp_bearer_token, token)

            conn
            |> assign(:mcp_authenticated, true)
            |> assign(:mcp_author_id, author_id)
            |> assign(:mcp_project_id, project_id)

          {:error, _reason} ->
            conn
            |> resp(401, "Invalid MCP Bearer token")
            |> halt()
        end

      _ ->
        conn
        |> resp(401, "Missing or invalid Authorization header")
        |> halt()
    end
  end
end
