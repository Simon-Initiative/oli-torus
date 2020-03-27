defmodule OliWeb.WorkspaceControllerTest do
  use OliWeb.ConnCase

  describe "index" do
    test "renders ui palette", %{conn: conn} do
      conn = get(conn, Routes.ui_palette_path(conn, :index))
      assert html_response(conn, 200) =~ "UI Palette"
    end
  end

  describe "projects" do
    test "displays all projects if the user has any"
    test "displays no projects if the user doesn't have any"
    test "directs to project#create to create a new project"
  end

  describe "account" do
    test "displays the page"
  end

end
