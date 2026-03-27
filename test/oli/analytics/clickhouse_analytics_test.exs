defmodule Oli.Analytics.ClickhouseAnalyticsTest do
  use ExUnit.Case, async: false

  import Mox

  alias Oli.Analytics.ClickhouseAnalytics
  alias Oli.Test.MockHTTP

  setup :verify_on_exit!

  setup do
    original_http = Application.get_env(:oli, :http_client)
    original_clickhouse = Application.get_env(:oli, :clickhouse)

    Application.put_env(:oli, :http_client, MockHTTP)

    Application.put_env(:oli, :clickhouse, %{
      host: "http://localhost",
      http_port: 8123,
      native_port: 9000,
      query_user: "test",
      query_password: "secret",
      admin_user: "admin",
      admin_password: "admin-secret",
      database: "analytics"
    })

    on_exit(fn ->
      if original_http do
        Application.put_env(:oli, :http_client, original_http)
      else
        Application.delete_env(:oli, :http_client)
      end

      if original_clickhouse do
        Application.put_env(:oli, :clickhouse, original_clickhouse)
      else
        Application.delete_env(:oli, :clickhouse)
      end
    end)

    :ok
  end

  describe "execute_query/3 error handling" do
    test "uses query credentials by default" do
      expect(MockHTTP, :post, fn _url, _body, headers, _opts ->
        assert {"X-ClickHouse-User", "test"} in headers
        assert {"X-ClickHouse-Key", "secret"} in headers
        refute {"X-ClickHouse-User", "admin"} in headers
        {:ok, %{status_code: 200, body: ~s({"data":[]})}}
      end)

      assert {:ok, _response} = ClickhouseAnalytics.execute_query("SELECT 1", "test query creds")
    end

    test "uses admin credentials only when explicitly requested" do
      expect(MockHTTP, :post, fn _url, _body, headers, _opts ->
        assert {"X-ClickHouse-User", "admin"} in headers
        assert {"X-ClickHouse-Key", "admin-secret"} in headers
        refute {"X-ClickHouse-User", "test"} in headers
        {:ok, %{status_code: 200, body: ~s({"data":[]})}}
      end)

      assert {:ok, _response} =
               ClickhouseAnalytics.execute_query("SELECT 1", "test admin creds",
                 credential: :admin
               )
    end

    test "returns an error when ClickHouse responds with a non-200 status" do
      expect(MockHTTP, :post, fn _url, _body, _headers, _opts ->
        {:ok, %{status_code: 500, body: "boom"}}
      end)

      assert {:error, message} =
               ClickhouseAnalytics.execute_query("SELECT 1", "test non-200")

      assert message =~ "status 500"
      assert message =~ "boom"
    end

    test "returns an error when the HTTP client fails" do
      expect(MockHTTP, :post, fn _url, _body, _headers, _opts ->
        {:error, :timeout}
      end)

      assert {:error, message} =
               ClickhouseAnalytics.execute_query("SELECT 1", "test timeout")

      assert message =~ "HTTP request"
      assert message =~ "timeout"
    end

    test "returns an error for empty queries" do
      assert {:error, "Empty query"} = ClickhouseAnalytics.execute_query("")
    end

    test "returns an error when query credentials are not configured" do
      Application.put_env(:oli, :clickhouse, %{
        host: "http://localhost",
        http_port: 8123,
        native_port: 9000,
        query_user: nil,
        query_password: nil,
        admin_user: "admin",
        admin_password: "admin-secret",
        database: "analytics"
      })

      assert {:error, message} =
               ClickhouseAnalytics.execute_query("SELECT 1", "test missing query creds")

      assert message =~ "ClickHouse query credentials are not configured"
      assert message =~ "CLICKHOUSE_QUERY_USER"
    end

    test "returns an error when admin credentials are not configured" do
      Application.put_env(:oli, :clickhouse, %{
        host: "http://localhost",
        http_port: 8123,
        native_port: 9000,
        query_user: "test",
        query_password: "secret",
        admin_user: nil,
        admin_password: nil,
        database: "analytics"
      })

      assert {:error, message} =
               ClickhouseAnalytics.execute_query("SELECT 1", "test missing admin creds",
                 credential: :admin
               )

      assert message =~ "ClickHouse admin credentials are not configured"
      assert message =~ "CLICKHOUSE_ADMIN_USER"
    end
  end
end
