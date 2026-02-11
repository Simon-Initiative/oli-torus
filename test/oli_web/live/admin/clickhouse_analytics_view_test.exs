defmodule OliWeb.Admin.ClickHouseAnalyticsViewTest do
  use OliWeb.ConnCase, async: false

  import Mox
  import Phoenix.LiveViewTest

  alias Oli.Test.MockHTTP
  alias OliWeb.Admin.ClickHouseAnalyticsView

  @route Routes.live_path(OliWeb.Endpoint, ClickHouseAnalyticsView)

  setup :verify_on_exit!
  setup :set_mox_global
  setup [:admin_conn, :enable_clickhouse_feature, :stub_clickhouse_config]

  test "shows an error when ClickHouse health check fails", %{conn: conn} do
    expect(MockHTTP, :post, fn _url, _body, _headers, _opts ->
      {:error, :econnrefused}
    end)

    {:ok, view, _html} = live(conn, @route)

    assert render_async(view) =~ "ClickHouse health check failed"
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
      user: "test",
      password: "secret",
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
end
