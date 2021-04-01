defmodule OliWeb.StaticPageController do
  use OliWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def unauthorized(conn, _params) do
    render conn, "unauthorized.html"
  end

  def keep_alive(conn, _pararms) do
    conn
    |> send_resp(200, "Ok")
  end
end
