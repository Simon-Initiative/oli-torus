defmodule OliWeb.UIPaletteController do
  use OliWeb, :controller

  alias Oli.Dev.UIPalette

  def index(conn, _params) do
    render(conn, "index.html")
  end

end
