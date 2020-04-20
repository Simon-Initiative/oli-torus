defmodule Oli.Plugs.Protect do
  import Plug.Conn
  alias Oli.Plugs.SetCurrentUser

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_author] do
      nil ->
        conn = SetCurrentUser.set_author(fetch_session(conn))

        case conn.assigns[:current_author] do
          nil ->
            conn
            |> Phoenix.Controller.redirect(to: OliWeb.Router.Helpers.auth_path(conn, :signin))
            |> Phoenix.Controller.halt()
          _ -> conn
        end
      _ -> conn
    end
  end
end
