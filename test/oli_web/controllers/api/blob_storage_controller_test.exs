defmodule OliWeb.Api.BlobStorageControllerTest do
  use OliWeb.ConnCase

  alias Oli.Seeder
  import Mox

  @moduledoc """
  This module tests the BlobStorageController, which provides endpoints for reading
  and writing text blobs by a client API that asserts the data is stored as JSON strings.

  This isn't much of a test, but it does ensure that the controller is set up correctly
  and that the expected behavior is implemented for reading and writing text blobs.
  It uses Mox to mock the ExAws requests to S3, allowing us to test the controller
  without actually making network requests.
  """

  describe "blob storage controller" do
    setup [:setup_session]

    test "can read regular keys as a pure text, but psuedo JSON API", %{
      conn: conn
    } do

      expect(Oli.Test.MockAws, :request, 1, fn %ExAws.Operation.S3{} ->
        {:ok, %{status_code: 200, body: "{}"}}
      end)

      conn = get(conn, Routes.blob_storage_path(conn, :read_key, "some-key"))

      text = text_response(conn, 200)
      assert text == "{}"
    end

    test "can read user scoped keys as a pure text, but psuedo JSON API", %{
      conn: conn
    } do

      expect(Oli.Test.MockAws, :request, 1, fn %ExAws.Operation.S3{} ->
        {:ok, %{status_code: 200, body: "{}"}}
      end)

      conn = get(conn, Routes.blob_storage_path(conn, :read_user_key, "some-key"))

      text = text_response(conn, 200)
      assert text == "{}"
    end

    test "can write regular keys as a pure text, but psuedo JSON API", %{
      conn: conn
    } do

      expect(Oli.Test.MockAws, :request, 1, fn %ExAws.Operation.S3{} ->
        {:ok, %{status_code: 200, body: "{}"}}
      end)

      conn =
        conn
        |> put_req_header("content-type", "text/plain")
        |> put(Routes.blob_storage_path(conn, :write_key, "some-key"), "raw text")

      text = text_response(conn, 200)
      assert text == "{\"result\": \"success\"}"
    end

    test "can write user scoped keys as a pure text, but psuedo JSON API", %{
      conn: conn
    } do

      expect(Oli.Test.MockAws, :request, 1, fn %ExAws.Operation.S3{} ->
        {:ok, %{status_code: 200, body: "{}"}}
      end)

      conn =
        conn
        |> put_req_header("content-type", "text/plain")
        |> put(Routes.blob_storage_path(conn, :write_user_key, "some-key"), "raw text")

      text = text_response(conn, 200)
      assert text == "{\"result\": \"success\"}"
    end

  end

  defp setup_session(%{conn: conn}) do
    user = user_fixture()
    user2 = user_fixture()

    map = Seeder.base_project_with_resource2()

    section =
      section_fixture(%{
        context_id: "some-context-id",
        base_project_id: map.project.id,
        institution_id: map.institution.id,
        open_and_free: false
      })

    Oli.Lti.TestHelpers.all_default_claims()
    |> put_in(["https://purl.imsglobal.org/spec/lti/claim/context", "id"], section.slug)
    |> cache_lti_params(user.id)

    conn =
      Plug.Test.init_test_session(conn, lti_session: nil)
      |> log_in_author(map.author)
      |> log_in_user(user)

    {:ok,
     conn: conn,
     map: map,
     author: map.author,
     institution: map.institution,
     user: user,
     user2: user2,
     project: map.project,
     publication: map.publication,
     section: section}
  end
end
