defmodule OliWeb.Plugs.SessionContext do
  import Plug.Conn

  alias OliWeb.Common.SessionContext

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> assign(:ctx, SessionContext.init(conn))
  end
end
