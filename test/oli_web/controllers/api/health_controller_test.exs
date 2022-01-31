defmodule OliWeb.HealthControllerTest do
  @moduledoc false

  use OliWeb.ConnCase

  describe "index" do
    test "index", %{conn: conn} do
      conn = get(conn, Routes.health_path(conn, :index))

      assert json_response(conn, 200) == %{"status" => "Ayup!"}
    end
  end
end
