defmodule OliWeb.Admin.ClickHouseAnalyticsViewTest do
  use OliWeb.ConnCase, async: false

  import Mox
  import Phoenix.LiveViewTest

  alias Oli.Test.MockHTTP
  alias OliWeb.Admin.ClickHouseAnalyticsView

  @route Routes.live_path(OliWeb.Endpoint, ClickHouseAnalyticsView)

  defmodule FakeTasks do
    def run(kind, opts) do
      sink = Keyword.fetch!(opts, :sink)
      sink.(%{level: :info, message: "#{kind} started", metadata: %{step: "start"}})
      sink.(%{level: :info, message: "#{kind} finished", metadata: %{step: "finish"}})
      :ok
    end
  end

  setup :verify_on_exit!
  setup :set_mox_global
  setup [:admin_conn, :enable_clickhouse_feature, :stub_clickhouse_config, :stub_phase_four_env]

  test "shows setup when ClickHouse is reachable but uninitialized and hides dangerous operations",
       %{conn: conn} do
    stub_clickhouse_http(%{database_exists: false, raw_events_exists: false})

    {:ok, view, _html} = live(conn, @route)

    html = render_async(view)

    assert html =~ "Run Migrate Up"
    assert html =~ "Run Migrate Down"
    assert html =~ "Initialize Database"
    refute html =~ "Create Database"
    refute html =~ "Drop Database"
    refute html =~ "Reset Database"

    [button_html] = Regex.run(~r/<button[^>]*phx-value-kind="setup"[^>]*>/, html)
    refute Regex.match?(~r/\sdisabled(?:=| |>)/, button_html)
  end

  test "does not render setup when the database is already initialized", %{conn: conn} do
    stub_clickhouse_http(%{database_exists: true, raw_events_exists: true})

    {:ok, view, _html} = live(conn, @route)

    html = render_async(view)

    assert html =~ "Run Migrate Up"
    assert html =~ "Run Migrate Down"
    refute html =~ "Initialize Database"
  end

  test "shows durable progress and success messages for supported operations", %{conn: conn} do
    stub_clickhouse_http(%{database_exists: false, raw_events_exists: false})

    {:ok, view, _html} = live(conn, @route)
    _ = render_async(view)

    render_click(element(view, "button[phx-value-kind=\"migrate_up\"]"))

    html = render_async(view)

    assert html =~ "Migrate Up"
    assert html =~ "migrate_up started"
    assert html =~ "migrate_up finished"
    assert html =~ "Operation completed successfully."
    assert html =~ "COMPLETED"
  end

  test "shows an error when ClickHouse health check fails", %{conn: conn} do
    stub(MockHTTP, :post, fn _url, _body, _headers, _opts ->
      {:error, :econnrefused}
    end)

    {:ok, view, _html} = live(conn, @route)

    assert render_async(view) =~ "ClickHouse health check failed"
  end

  test "shows an error when ClickHouse admin credentials are not configured", %{conn: conn} do
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

    {:ok, view, _html} = live(conn, @route)

    html = render_async(view)
    assert html =~ "ClickHouse health check failed"
    assert html =~ "ClickHouse admin credentials are not configured"
  end

  defp enable_clickhouse_feature(_) do
    Application.put_env(:oli, :clickhouse_olap_enabled?, true)
    Oli.Features.bootstrap_feature_states()
    Oli.Features.change_state("clickhouse-olap", :enabled)
    :ok
  end

  defp stub_clickhouse_config(_) do
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
      restore_env(:http_client, original_http)
      restore_env(:clickhouse, original_clickhouse)
    end)

    :ok
  end

  defp stub_phase_four_env(_) do
    original_tasks = Application.get_env(:oli, :clickhouse_tasks_module)
    original_mode = Application.get_env(:oli, :clickhouse_admin_operations_mode)

    Application.put_env(:oli, :clickhouse_tasks_module, FakeTasks)
    Application.put_env(:oli, :clickhouse_admin_operations_mode, :sync)

    on_exit(fn ->
      restore_env(:clickhouse_tasks_module, original_tasks)
      restore_env(:clickhouse_admin_operations_mode, original_mode)
    end)

    :ok
  end

  defp stub_clickhouse_http(%{
         database_exists: database_exists,
         raw_events_exists: raw_events_exists
       }) do
    stub(MockHTTP, :post, fn _url, body, _headers, _opts ->
      {:ok, %{status_code: 200, body: response_body(body, database_exists, raw_events_exists)}}
    end)
  end

  defp response_body(body, database_exists, raw_events_exists) do
    cond do
      String.contains?(body, "version() AS version") ->
        Jason.encode!(%{
          "data" => [
            %{
              "version" => "24.1",
              "uptime_seconds" => 120,
              "timezone" => "UTC",
              "hostname" => "clickhouse.test",
              "server_time" => "2026-04-02 12:00:00",
              "current_database" => "analytics",
              "configured_database" => "analytics"
            }
          ]
        })

      String.contains?(body, "metadata_modification_time") ->
        Jason.encode!(%{
          "data" =>
            if(raw_events_exists,
              do: [
                %{
                  "name" => "raw_events",
                  "engine" => "MergeTree",
                  "total_rows" => 42,
                  "total_bytes" => 2048,
                  "metadata_modification_time" => "2026-04-02 12:00:00"
                }
              ],
              else: []
            )
        })

      String.contains?(body, "FROM system.parts") ->
        Jason.encode!(%{
          "data" => [
            %{
              "active_parts" => 1,
              "last_part_modification" => "2026-04-02 12:00:00",
              "bytes_on_disk" => 2048,
              "rows_on_disk" => 42
            }
          ]
        })

      String.contains?(body, "FROM system.databases") ->
        Jason.encode!(%{"data" => [%{"exists" => if(database_exists, do: 1, else: 0)}]})

      String.contains?(body, "count() > 0 AS exists") and
          String.contains?(body, "FROM system.tables") ->
        Jason.encode!(%{"data" => [%{"exists" => if(raw_events_exists, do: 1, else: 0)}]})

      true ->
        Jason.encode!(%{"data" => []})
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:oli, key)
  defp restore_env(key, value), do: Application.put_env(:oli, key, value)
end
