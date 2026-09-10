defmodule OliWeb.ExperimentControllerTest do
  use OliWeb.ConnCase

  import Oli.Factory

  describe "disabled UpGrade JSON exports" do
    setup [:admin_conn]

    setup do
      project = insert(:project)
      [project: project]
    end

    @tag capture_log: true
    test "segment export returns gone", %{conn: conn, project: project} do
      conn = get(conn, Routes.experiment_path(conn, :segment_download, project.slug))

      assert response(conn, 410) == "UpGrade experiment JSON export has been removed"
    end

    @tag capture_log: true
    test "experiment export returns gone", %{conn: conn, project: project} do
      conn = get(conn, Routes.experiment_path(conn, :experiment_download, project.slug))

      assert response(conn, 410) == "UpGrade experiment JSON export has been removed"
    end
  end
end
