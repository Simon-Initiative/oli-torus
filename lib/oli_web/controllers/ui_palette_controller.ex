defmodule OliWeb.UIPaletteController do
  use OliWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
