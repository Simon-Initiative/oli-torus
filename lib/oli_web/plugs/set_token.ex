defmodule OliWeb.Plugs.SetToken do
  @moduledoc """
  Set the client facing 'user_token' in the socket assigns.

  Not to be confused with the 'user_token' in the session which is used for server side
  authentication.
  """
  import Plug.Conn

  def init(_opts), do: nil

  def call(conn, _opts) do
    case conn.assigns[:current_user] do
      nil ->
        conn

      user ->
        token =
          case conn.assigns[:user_session] do
            nil -> Phoenix.Token.sign(conn, "user socket", user.sub)
            session -> OliWeb.SecureSocket.sign(conn, session)
          end

        assign(conn, :user_token, token)
    end
  end
end
