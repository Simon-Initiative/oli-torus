defmodule OliWeb.IngestControllerTest do
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias OliWeb.Router.Helpers, as: Routes

  describe "index" do
    test "returns ok when admin is logged in", %{conn: conn} do
      {:ok, conn: conn, admin: _} = admin_conn(%{conn: conn})
      conn = get(conn, Routes.ingest_path(conn, :index))

      assert response(conn, 200) =~ "<title>\n      Ingest"
    end

    test "redirects when admin is not logged in", %{conn: conn} do
      conn = get(conn, Routes.ingest_path(conn, :index))

      assert html_response(conn, 302) =~
               "<html><body>You are being <a href=\"/authors/log_in\">redirected</a>.</body></html>"
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

  describe "process" do
    setup [:admin_conn]

    test "mounts with authenticated author when legacy author id session key is missing", %{
      conn: conn,
      admin: admin
    } do
      digest_dir = "_digests"
      digest_path = "#{digest_dir}/#{admin.id}-digest.zip"

      File.mkdir_p!(digest_dir)
      File.write!(digest_path, "digest")

      on_exit(fn -> File.rm(digest_path) end)

      conn = delete_session(conn, :current_author_id)

      {:ok, _view, html} = live(conn, ~p"/admin/ingest/process")

      assert html =~ "Course Ingestion"
    end
  end

  describe "index_csv" do
    test "can be accessed by an Admin", %{conn: conn} do
      project = insert(:project)

      {:ok, conn: conn, admin: _} = admin_conn(%{conn: conn})
      conn = get(conn, ~p"/admin/#{project.slug}/import/index")

      assert response(conn, 200) =~ ~s{<h3 class="display-6">CSV Import</h3>}
    end

    test "can not be accessed by an author", %{conn: conn} do
      project = insert(:project)

      {:ok, conn: conn, author: _} = author_conn(%{conn: conn})

      conn = get(conn, ~p"/admin/#{project.slug}/import/index")

      assert redirected_to(conn, 302) ==
               "/workspaces/course_author"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "You are not authorized to access this page."
    end

    test "can not be accessed by a user", %{conn: conn} do
      project = insert(:project)

      {:ok, conn: conn, user: _} = user_conn(%{conn: conn})

      conn = get(conn, ~p"/admin/#{project.slug}/import/index")

      assert redirected_to(conn, 302) ==
               "/authors/log_in"
    end
  end

  describe "upload_csv" do
    setup [:admin_conn]

    test "redirects to CSVImportView view when attaching a valid file", %{conn: conn} do
      file_upload = %{
        "digest" => %Plug.Upload{
          content_type: "text/csv",
          filename: "some.txt",
          path: "some_path"
        }
      }

      conn =
        post(conn, Routes.ingest_path(conn, :upload_csv, "some_project_slug"), %{
          upload_csv: file_upload
        })

      assert redirected_to(conn, 302) == ~p"/admin/some_project_slug/import/csv"
    end

    test "redirects to index csv view when there is no file attachment", %{conn: conn} do
      conn =
        post(conn, Routes.ingest_path(conn, :upload_csv, "some_project_slug"), %{})

      assert redirected_to(conn, 302) == ~p"/admin/some_project_slug/import/index"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "A valid file must be attached"
    end
  end
end
