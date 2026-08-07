defmodule Oli.Clickhouse.TasksTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Oli.Clickhouse.Tasks

  describe "reset/0" do
    test "requires explicit confirmation before proceeding" do
      output =
        capture_io("no\n", fn ->
          assert :cancelled = Tasks.reset()
        end)

      assert output =~
               "WARNING! This will completely erase all data from the ClickHouse database."

      assert output =~ "Enter RESET CLICKHOUSE to continue"
      assert output =~ "--force to bypass"
      assert output =~ "ABORTED: Operation was not confirmed by user."
    end
  end

  describe "clickhouse_http_url/2" do
    test "preserves a configured URL scheme without duplicating it" do
      config = %{host: "http://clickhouse-staging.oli.cmu.edu", http_port: 8123}

      assert Tasks.clickhouse_http_url(config) ==
               "http://clickhouse-staging.oli.cmu.edu:8123/"
    end

    test "adds a default scheme to a bare hostname and selects the configured database" do
      config = %{host: "clickhouse.example.com", http_port: 8443}

      assert Tasks.clickhouse_http_url(config, database: "oli analytics") ==
               "http://clickhouse.example.com:8443/?database=oli+analytics"
    end

    test "does not include credentials supplied in the host URL" do
      config = %{host: "https://old:secret@clickhouse.example.com/path", http_port: 8443}

      assert Tasks.clickhouse_http_url(config) == "https://clickhouse.example.com:8443/"
    end

    test "converts a TCP endpoint to an HTTP URL without retaining its native port or path" do
      config = %{
        host: "tcp://old:secret@clickhouse.example.com:9000/analytics",
        http_port: 8123
      }

      assert Tasks.clickhouse_http_url(config, database: "analytics") ==
               "http://clickhouse.example.com:8123/?database=analytics"
    end
  end

  describe "clickhouse_native_endpoint/2" do
    test "removes an HTTP scheme from the host and excludes credentials" do
      config = %{
        host: "http://clickhouse-staging.oli.cmu.edu",
        native_port: 9000,
        user: "admin",
        password: "super-secret"
      }

      endpoint = Tasks.clickhouse_native_endpoint(config, "oli_analytics_ab_testing")

      assert endpoint ==
               "tcp://clickhouse-staging.oli.cmu.edu:9000/oli_analytics_ab_testing"

      refute endpoint =~ "admin"
      refute endpoint =~ "super-secret"
    end
  end
end
