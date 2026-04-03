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

  test "shows setup card first, enabled when available, and hides dangerous operations",
       %{conn: conn} do
    stub_clickhouse_http(%{
      database_exists: false,
      raw_events_exists: false,
      pending_migrations: 1
    })

    {:ok, view, _html} = live(conn, @route)

    html = render_async(view)

    assert String.contains?(html, "Setup Database")

    assert String.contains?(
             html,
             "Required before torus analytics can use this ClickHouse database."
           )

    assert html =~ "✓ Reachable"
    assert html =~ "✗ Database exists"
    assert html =~ "✗ Table exists"
    assert html =~ "1 pending migration"
    assert html =~ ">Setup Database<"
    assert html =~ ">Migrate Up<"
    assert html =~ ">Migrate Down<"
    refute html =~ "Create Database"
    refute html =~ "Drop Database"
    refute html =~ "Reset Database"

    {setup_index, _} = :binary.match(html, "Setup Database")
    {migrate_up_index, _} = :binary.match(html, "Migrate Up")
    assert setup_index < migrate_up_index
    [button_html] = Regex.run(~r/<button[^>]*phx-value-kind="setup"[^>]*>/, html)
    refute Regex.match?(~r/\sdisabled(?:=| |>)/, button_html)
  end

  test "shows setup card disabled when the database is already initialized", %{conn: conn} do
    stub_clickhouse_http(%{
      database_exists: true,
      raw_events_exists: true,
      pending_migrations: 0
    })

    {:ok, view, _html} = live(conn, @route)

    html = render_async(view)

    assert html =~ "Setup Database"
    assert html =~ "Required before torus analytics can use this ClickHouse database."
    assert html =~ "✓ Reachable"
    assert html =~ "✓ Database exists"
    assert html =~ "✓ Table exists"
    assert html =~ "No pending migrations"
    assert html =~ ">Setup Database<"
    assert html =~ ">Migrate Up<"
    assert html =~ ">Migrate Down<"

    [button_html] = Regex.run(~r/<button[^>]*phx-value-kind="setup"[^>]*>/, html)
    assert Regex.match?(~r/\sdisabled(?:=| |>)/, button_html)

    [migrate_button_html] = Regex.run(~r/<button[^>]*phx-value-kind="migrate_up"[^>]*>/, html)
    assert Regex.match?(~r/\sdisabled(?:=| |>)/, migrate_button_html)
  end

  test "shows current-operation progress and success messages for supported operations", %{
    conn: conn
  } do
    stub_clickhouse_http(%{
      database_exists: false,
      raw_events_exists: false,
      pending_migrations: 1
    })

    {:ok, view, _html} = live(conn, @route)
    _ = render_async(view)

    render_click(element(view, "button[phx-value-kind=\"migrate_up\"]"))
    assert render(view) =~ "Confirm Migrate Up"

    render_click(element(view, "button[phx-click=\"confirm_clickhouse_operation\"]"))

    html = render_async(view)

    assert html =~ "Migrate Up"
    assert html =~ "migrate_up started"
    assert html =~ "migrate_up finished"
    assert html =~ "Operation completed successfully."
    assert html =~ "COMPLETED"
    refute html =~ "Recent Operation History"
  end

  test "canceling migration confirmation modal does not start the operation", %{conn: conn} do
    stub_clickhouse_http(%{
      database_exists: false,
      raw_events_exists: false,
      pending_migrations: 1
    })

    {:ok, view, _html} = live(conn, @route)
    _ = render_async(view)

    render_click(element(view, "button[phx-value-kind=\"migrate_down\"]"))
    assert render(view) =~ "Confirm Migrate Down"

    render_click(element(view, "button[phx-click=\"cancel_clickhouse_operation\"]"))

    html = render(view)

    refute html =~ "Confirm Migrate Down"
    refute html =~ "migrate_down started"
    refute html =~ "Current Operation"
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
         raw_events_exists: raw_events_exists,
         pending_migrations: pending_migrations
       }) do
    stub(MockHTTP, :post, fn _url, body, _headers, _opts ->
      {:ok,
       %{
         status_code: 200,
         body: response_body(body, database_exists, raw_events_exists, pending_migrations)
       }}
    end)
  end

  defp stub_clickhouse_http(%{
         database_exists: database_exists,
         raw_events_exists: raw_events_exists
       }) do
    stub_clickhouse_http(%{
      database_exists: database_exists,
      raw_events_exists: raw_events_exists,
      pending_migrations: if(raw_events_exists, do: 0, else: 1)
    })
  end

  defp response_body(body, database_exists, raw_events_exists, pending_migrations) do
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
        exists =
          cond do
            String.contains?(body, "name = 'raw_events'") -> raw_events_exists
            String.contains?(body, "name = 'goose_db_version'") -> pending_migrations == 0
            true -> false
          end

        Jason.encode!(%{"data" => [%{"exists" => if(exists, do: 1, else: 0)}]})

      String.contains?(body, "max(version_id) AS version_id") ->
        Jason.encode!(%{
          "data" => [
            %{
              "version_id" => if(pending_migrations == 0, do: "20260326213833", else: nil)
            }
          ]
        })

      true ->
        Jason.encode!(%{"data" => []})
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:oli, key)
  defp restore_env(key, value), do: Application.put_env(:oli, key, value)
end
