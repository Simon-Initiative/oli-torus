defmodule OliWeb.Plugs.HeaderSizeLogger do
  @moduledoc """
  A plug to log the size of request and response headers and send an event to
  Appsignal in case the size exceeds a threshold.

  This plug was developed as a complementary work for MER-3552.
  MER-3552 aimed to fix the bug where users experienced 431 errors because somehow,
  their HTTP Header sizes are growing beyond the max configured size.
  """

  import Plug.Conn
  require Logger

  @threshold Application.compile_env(:oli, OliWeb.Endpoint, [])
             |> Keyword.get(:http, [])
             |> Keyword.get(:protocol_options, [])
             |> Keyword.get(:max_header_value_length)

  def init(opts) do
    # Allow passing a custom capture module for testing
    capture_module = Keyword.get(opts, :capture_module, Oli.Utils.Appsignal)
    Keyword.put(opts, :capture_module, capture_module)
  end

  def call(conn, opts) do
    conn
    |> maybe_log_request_header_size(opts)
    |> register_before_send(&maybe_log_response_header_size(&1, opts))
  end

  defp maybe_log_request_header_size(conn, opts) do
    request_header_size = calculate_headers_size(conn.req_headers)

    if request_header_size > @threshold do
      log_to_analytics("Request", request_header_size, conn, opts)
    end

    conn
  end

  defp maybe_log_response_header_size(conn, opts) do
    response_header_size = calculate_headers_size(conn.resp_headers)

    if response_header_size > @threshold do
      log_to_analytics("Response", response_header_size, conn, opts)
    end

    conn
  end

  defp calculate_headers_size(headers) do
    Enum.reduce(headers, 0, fn {key, value}, acc ->
      # +4 for ": " and "\r\n"
      acc + byte_size(key) + byte_size(value) + 4
    end)
  end

  defp log_to_analytics(type, size, conn, opts) do
    additional_data = %{
      type: type,
      size: size,
      headers: if(type == "Request", do: conn.req_headers, else: conn.resp_headers),
      path: conn.request_path,
      method: conn.method,
      user_agent: get_req_header(conn, "user-agent") |> List.first() || "",
      ip: conn.remote_ip |> :inet.ntoa() |> to_string()
    }

    message = "#{type} headers size (#{size} bytes) exceeds the threshold of #{@threshold} bytes."

    capture_module = opts[:capture_module]
    capture_module.capture_error("#{message}: #{inspect(additional_data)}")

    Logger.warning("#{message}: #{inspect(additional_data)}")
  end
end
