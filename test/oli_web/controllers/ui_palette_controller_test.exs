defmodule OliWeb.UIPaletteControllerTest do
  use OliWeb.ConnCase

  alias Oli.Dev

  describe "index" do
    test "renders ui palette", %{conn: conn} do
      conn = get(conn, Routes.ui_palette_path(conn, :index))
      assert html_response(conn, 200) =~ "UI Palette"
    end
  end

end
