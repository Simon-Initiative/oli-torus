defmodule OliWeb.IngestLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  alias OliWeb.Router.Helpers, as: Routes

  @live_view_ingest_route Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.Ingest)

  defp simulate_open_zip(path) do
    tmp_dir = System.tmp_dir!()
    zip_tmp_filepath = Path.join([tmp_dir, "digest.zip"])

    files = File.ls!(path) |> Enum.map(&String.to_charlist/1)

    {:ok, _filename} = :zip.create(zip_tmp_filepath, files, cwd: path)

    zip_tmp_filepath
  end

  defp upload_file(file_name, conn) do
    path = simulate_open_zip("./test/support/digests/#{file_name}")

    file_upload = %{
      "digest" => %Plug.Upload{
        content_type: "application/zip",
        filename: file_name,
        path: path
      }
    }

    post(conn, Routes.ingest_path(conn, :upload), %{
      upload: file_upload
    })
  end

  describe "user cannot access when is not logged in" do
    test "redirects to new session when accessing the ingest project view", %{
      conn: conn
    } do
      redirect_path = "/authoring/session/new?request_path=%2Fadmin%2Fingest"

      {:error, {:redirect, %{to: ^redirect_path}}} = live(conn, @live_view_ingest_route)
    end
  end

  describe "ingest project" do
    setup [:admin_conn]

    test "shows error message when media manifest file is not loaded", %{conn: conn, admin: admin} do
      conn = upload_file("digest_4", conn)

      assert redirected_to(conn, 302) == Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.IngestV2)

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(admin, OliWeb.Pow.PowHelpers.get_pow_config(:author))

      {:ok, view, _html} =
        live(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.IngestV2, %{
            current_author_id: conn.assigns.current_author.id
          })
        )

      view
      |> element("button[phx-click=\"preprocess\"")
      |> render_click()

      wait_until(
        fn ->
          assert has_element?(
                   view,
                   "h3[class=\"display-6\"]",
                   "Course Ingestion"
                 )

          assert has_element?(
                   view,
                   "table > tbody > tr > td:first-child",
                   "Could not locate required file _media-manifest.json in archive"
                 )
        end,
        1_000
      )
    end

    test "shows error message when hierarchy file is not loaded", %{conn: conn, admin: admin} do
      conn = upload_file("digest_5", conn)

      assert redirected_to(conn, 302) == Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.IngestV2)

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(admin, OliWeb.Pow.PowHelpers.get_pow_config(:author))

      {:ok, view, _html} =
        live(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.IngestV2, %{
            current_author_id: conn.assigns.current_author.id
          })
        )

      view
      |> element("button[phx-click=\"preprocess\"")
      |> render_click()

      wait_until(
        fn ->
          assert has_element?(
                   view,
                   "h3[class=\"display-6\"]",
                   "Course Ingestion"
                 )

          assert has_element?(
                   view,
                   "table > tbody > tr > td:first-child",
                   "Could not locate required file _hierarchy.json in archive"
                 )
        end,
        1_000
      )
    end

    test "shows error message when project file is not loaded", %{conn: conn, admin: admin} do
      conn = upload_file("digest_6", conn)

      assert redirected_to(conn, 302) == Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.IngestV2)

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(admin, OliWeb.Pow.PowHelpers.get_pow_config(:author))

      {:ok, view, _html} =
        live(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.IngestV2, %{
            current_author_id: conn.assigns.current_author.id
          })
        )

      view
      |> element("button[phx-click=\"preprocess\"")
      |> render_click()

      wait_until(
        fn ->
          assert has_element?(
                   view,
                   "h3[class=\"display-6\"]",
                   "Course Ingestion"
                 )

          assert has_element?(
                   view,
                   "table > tbody > tr > td:first-child",
                   "Could not locate required file _project.json in archive"
                 )
        end,
        1_000
      )
    end

    test "shows error message when zip file does not have any file required", %{
      conn: conn,
      admin: admin
    } do
      conn = upload_file("digest_1", conn)

      assert redirected_to(conn, 302) == Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.IngestV2)

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(admin, OliWeb.Pow.PowHelpers.get_pow_config(:author))

      {:ok, view, _html} =
        live(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.IngestV2, %{
            current_author_id: conn.assigns.current_author.id
          })
        )

      view
      |> element("button[phx-click=\"preprocess\"")
      |> render_click()

      wait_until(
        fn ->
          assert has_element?(
                   view,
                   "h3[class=\"display-6\"]",
                   "Course Ingestion"
                 )

          assert has_element?(
                   view,
                   "table > tbody > tr > td:first-child",
                   "Could not locate required file _media-manifest.json in archive"
                 )

          assert has_element?(
                   view,
                   "table > tbody > tr > td:first-child",
                   "Could not locate required file _hierarchy.json in archive"
                 )

          assert has_element?(
                   view,
                   "table > tbody > tr > td:first-child",
                   "Could not locate required file _project.json in archive"
                 )
        end,
        1_000
      )
    end

    test "there are no show error messages when file is loaded ok", %{
      conn: conn,
      admin: admin
    } do
      conn = upload_file("digest_3", conn)

      assert redirected_to(conn, 302) == Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.IngestV2)

      conn =
        recycle(conn)
        |> Pow.Plug.assign_current_user(admin, OliWeb.Pow.PowHelpers.get_pow_config(:author))

      {:ok, view, _html} =
        live(
          conn,
          Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.IngestV2, %{
            current_author_id: conn.assigns.current_author.id
          })
        )

      view
      |> element("button[phx-click=\"preprocess\"")
      |> render_click()

      wait_until(
        fn ->
          refute has_element?(
                   view,
                   "table > thead > tr > th:first-child",
                   "Error"
                 )

          assert has_element?(
                   view,
                   "h3[class=\"display-6\"]",
                   "Course Ingestion"
                 )

          assert has_element?(
                   view,
                   "p[class=\"px-5 py-2\"]",
                   "None exist"
                 )
        end,
        1_000
      )
    end

    @tag :skip
    test "show error message when no file is attached", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_ingest_route)

      view
      |> element("form[phx-submit=\"ingest\"")
      |> render_submit()

      assert has_element?(
               view,
               "div.alert.alert-danger",
               "Project archive is invalid. Archive must be a valid zip file"
             )
    end

    @tag :skip
    test "show error message when attaching an invalid file", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_ingest_route)

      path = simulate_open_zip("./test/support/digests/digest_1")

      file_zip_1 =
        file_input(view, "#json-upload", :digest, [
          %{
            name: "digest_1.zip",
            content: File.read!(path),
            type: "zip"
          }
        ])

      render_upload(file_zip_1, "digest_1.zip")

      view
      |> element("form[phx-submit=\"ingest\"")
      |> render_submit()

      assert has_element?(
               view,
               "div.alert.alert-danger",
               "Project archive is invalid. Archive must include _project.json, _hierarchy.json and _media-manifest.json"
             )
    end

    @tag :skip
    test "show error message when attaching a file with invalid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_ingest_route)

      path = simulate_open_zip("./test/support/digests/digest_2")

      file_zip_2 =
        file_input(view, "#json-upload", :digest, [
          %{
            name: "digest_2.zip",
            content: File.read!(path),
            type: "zip"
          }
        ])

      render_upload(file_zip_2, "digest_2.zip")

      view
      |> element("form[phx-submit=\"ingest\"")
      |> render_submit()

      assert has_element?(
               view,
               "div.alert.alert-danger",
               "Project title not found in _project.json"
             )
    end

    @tag :skip
    test "show error message when attaching a file with invalid title of project", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_ingest_route)

      path = simulate_open_zip("./test/support/digests/digest_3")

      file_zip_3 =
        file_input(view, "#json-upload", :digest, [
          %{
            name: "digest_3.zip",
            content: File.read!(path),
            type: "zip"
          }
        ])

      render_upload(file_zip_3, "digest_3.zip")

      view
      |> element("form[phx-submit=\"ingest\"")
      |> render_submit()

      assert has_element?(
               view,
               "div.alert.alert-danger",
               "Project title cannot be empty in _project.json"
             )
    end
  end
end
