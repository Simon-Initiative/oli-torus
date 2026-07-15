defmodule OliWeb.PlaywrightSupportAssetControllerTest do
  use OliWeb.ConnCase, async: true

  describe "playwright support assets" do
    test "serves the embedded runtime stub", %{conn: conn} do
      conn = get(conn, "/superactivity/embedded/index.html")

      assert response_content_type(conn, :html) =~ "text/html"
      assert response(conn, 200) =~ "Embedded runtime stub loaded"
    end

    test "serves an allowed support asset", %{conn: conn} do
      conn = get(conn, "/test/support/image_coding_table.csv")

      assert response_content_type(conn, :csv) =~ "text/csv"
      assert response(conn, 200) =~ "name,value"
    end

    test "rejects unknown support assets", %{conn: conn} do
      conn = get(conn, "/test/support/does_not_exist.txt")

      assert response(conn, 404) == "Not found"
    end
  end
end
