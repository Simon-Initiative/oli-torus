defmodule OliWeb.PlaywrightSupportAssetControllerTest do
  use OliWeb.ConnCase, async: true

  import Mox

  alias Oli.Scenarios.PlaywrightAssetStorage

  setup :verify_on_exit!

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

  describe "private assets" do
    @token "playwright-test-token"

    setup do
      previous = Application.get_env(:oli, :playwright_scenario_token)
      Application.put_env(:oli, :playwright_scenario_token, @token)

      on_exit(fn ->
        Application.put_env(:oli, :playwright_scenario_token, previous)
      end)

      :ok
    end

    test "rejects requests without the scenario token", %{conn: conn} do
      conn = get(conn, "/test/assets/mer-5672/answers.json")

      assert response(conn, 401) == "unauthorized"
    end

    test "rejects requests with a wrong token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-playwright-scenario-token", "not-the-token")
        |> get("/test/assets/mer-5672/answers.json")

      assert response(conn, 401) == "unauthorized"
    end

    test "rejects keys containing directory traversal", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-playwright-scenario-token", @token)
        |> get("/test/assets/../secrets.txt")

      assert response(conn, 400) == "invalid_key"
    end

    test "rejects ambiguous asset keys before reaching the storage backend" do
      for key <- [
            "",
            "/bad/key",
            "bad//key",
            "bad/key/",
            "bad/./key",
            "bad/../key"
          ] do
        assert PlaywrightAssetStorage.get_object(key) == {:error, :invalid_key}

        assert PlaywrightAssetStorage.put_object(key, "body", "text/plain") ==
                 {:error, :invalid_key}
      end
    end

    test "returns 404 when the object does not exist", %{conn: conn} do
      expect(Oli.Test.MockAws, :request, fn %ExAws.Operation.S3{http_method: :get}, _config ->
        {:error, {:http_error, 404, %{}}}
      end)

      conn =
        conn
        |> put_req_header("x-playwright-scenario-token", @token)
        |> get("/test/assets/mer-5672/missing.zip")

      assert response(conn, 404) == "not_found"
    end

    test "serves an object from the assets bucket", %{conn: conn} do
      expect(Oli.Test.MockAws, :request, fn %ExAws.Operation.S3{
                                              http_method: :get,
                                              bucket: bucket,
                                              path: path
                                            },
                                            _config ->
        assert bucket == PlaywrightAssetStorage.bucket_name()
        assert path =~ "mer-5672/answers.json"

        {:ok,
         %{
           status_code: 200,
           body: ~s({"lesson": "data"}),
           headers: [{"Content-Type", "application/json"}]
         }}
      end)

      conn =
        conn
        |> put_req_header("x-playwright-scenario-token", @token)
        |> get("/test/assets/mer-5672/answers.json")

      assert response(conn, 200) == ~s({"lesson": "data"})
      assert response_content_type(conn, :json) =~ "application/json"
      assert get_resp_header(conn, "cache-control") == ["no-store"]
    end
  end
end
