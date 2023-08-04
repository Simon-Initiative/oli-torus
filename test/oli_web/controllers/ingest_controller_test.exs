defmodule OliWeb.IngestControllerTest do
  use OliWeb.ConnCase

  alias OliWeb.Router.Helpers, as: Routes

  describe "index" do
    test "returns ok when admin is logged in", %{conn: conn} do
      {:ok, conn: conn, admin: _} = admin_conn(%{conn: conn})
      conn = get(conn, Routes.ingest_path(conn, :index))

      assert response(conn, 200) =~ "<title data-suffix=\"\">Ingest</title>"
    end

    test "redirects when admin is not logged in", %{conn: conn} do
      conn = get(conn, Routes.ingest_path(conn, :index))

      assert html_response(conn, 302) =~
               "<html><body>You are being <a href=\"/authoring/session/new?request_path=%2Fadmin%2Fingest%2Fupload\">redirected</a>.</body></html>"
    end
  end

  describe "upload" do
    setup [:admin_conn]

    test "redirects to IngestV2 view when attaching a valid file", %{conn: conn} do
      file_upload = %{
        "digest" => %Plug.Upload{
          content_type: "application/zip",
          filename: "attachments.zip",
          path: "some_path"
        }
      }

      conn =
        post(conn, Routes.ingest_path(conn, :upload), %{
          upload: file_upload
        })

      assert redirected_to(conn, 302) == Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.IngestV2)
    end

    test "redirects to Course Ingestion view when there is no file attachment", %{conn: conn} do
      conn = post(conn, Routes.ingest_path(conn, :upload), %{})

      assert redirected_to(conn, 302) == Routes.ingest_path(conn, :index)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "A valid file must be attached"
    end
  end
end
