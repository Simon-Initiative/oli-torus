defmodule OliWeb.SetLiveCSRF do
  import Plug.Conn, only: [put_session: 3]

  def init(_opts), do: nil

  def call(conn, _opts), do: put_session(conn, :csrf_token, Phoenix.Controller.get_csrf_token())
end
