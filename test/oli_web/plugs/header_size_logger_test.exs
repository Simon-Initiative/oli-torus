defmodule OliWeb.Plugs.HeaderSizeLoggerTest do
  use ExUnit.Case, async: true

  import Mox
  import ExUnit.CaptureLog
  import Plug.Test
  import Plug.Conn

  alias OliWeb.Plugs.HeaderSizeLogger

  setup :set_mox_from_context
  setup :verify_on_exit!

  Mox.defmock(Oli.Utils.AppsignalMock, for: Oli.Utils.AppsignalBehaviour)

  defp get_threshold do
    Application.get_env(:oli, OliWeb.Endpoint, [])
    |> Keyword.get(:http, [])
    |> Keyword.get(:protocol_options, [])
    |> Keyword.get(:max_header_value_length, 4096)
  end

  @tag :flaky
  test "does not log when request headers are below threshold" do
    opts = HeaderSizeLogger.init(capture_module: Oli.Utils.AppsignalMock)

    conn =
      conn(:get, "/")
      |> put_req_header("user-agent", "test-agent")
      |> assign(:remote_ip, {127, 0, 0, 1})

    log = capture_log(fn -> HeaderSizeLogger.call(conn, opts) end)

    assert log == ""
  end

  test "logs and captures error when request headers exceed threshold" do
    threshold = get_threshold()

    expect(Oli.Utils.AppsignalMock, :capture_error, fn _message -> :ok end)

    opts = HeaderSizeLogger.init(capture_module: Oli.Utils.AppsignalMock)

    # header value that exceeds the threshold
    large_value = String.duplicate("a", threshold + 100)

    conn =
      conn(:get, "/")
      |> put_req_header("x-large-header", large_value)
      |> put_req_header("user-agent", "test-agent")
      |> assign(:remote_ip, {127, 0, 0, 1})

    expected_size =
      HeaderSizeLogger.calculate_headers_size(conn.req_headers)

    log = capture_log(fn -> HeaderSizeLogger.call(conn, opts) end)

    assert log =~
             "Request headers size (#{expected_size} bytes) exceeds the threshold of #{threshold} bytes."

    assert log =~ ~s(type: "Request")
    assert log =~ ~s(path: "/")
    assert log =~ ~s(method: "GET")
    assert log =~ ~s(user_agent: "test-agent")
    assert log =~ ~s(ip: "127.0.0.1")
  end

  test "does not log when response headers are below threshold" do
    opts = HeaderSizeLogger.init(capture_module: Oli.Utils.AppsignalMock)

    conn =
      conn(:get, "/")
      |> assign(:remote_ip, {127, 0, 0, 1})

    log =
      capture_log(fn ->
        conn
        |> HeaderSizeLogger.call(opts)
        |> send_resp(200, "OK")
      end)

    assert log == ""
  end

  test "logs and captures error when response headers exceed threshold" do
    threshold = get_threshold()

    expect(Oli.Utils.AppsignalMock, :capture_error, fn _message -> :ok end)

    opts = HeaderSizeLogger.init(capture_module: Oli.Utils.AppsignalMock)

    # header value that exceeds the threshold
    large_value = String.duplicate("b", threshold + 100)

    conn =
      conn(:get, "/")
      |> assign(:remote_ip, {127, 0, 0, 1})
      |> put_resp_header("x-large-header", large_value)

    log =
      capture_log(fn ->
        conn
        |> HeaderSizeLogger.call(opts)
        |> send_resp(200, "OK")
      end)

    expected_size = HeaderSizeLogger.calculate_headers_size(conn.resp_headers)

    assert log =~
             "Response headers size (#{expected_size} bytes) exceeds the threshold of #{threshold} bytes."

    assert log =~ ~s(type: "Response")
    assert log =~ ~s(path: "/")
    assert log =~ ~s(method: "GET")
    assert log =~ ~s(user_agent: "")
    assert log =~ ~s(ip: "127.0.0.1")
  end
end
