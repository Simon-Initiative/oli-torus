defmodule OliWeb.Plugs.HeaderSizeLogger do
  @moduledoc """
  A plug to log the size of request and response headers and send an event to
  Appsignal in case the size exceeds a threshold.

  This plug was developed as a complementary work for MER-3552.
  MER-3552 aimed to fix the bug where users experienced 431 errors because somehow,
  their HTTP Header sizes are growing beyond the max configured size.
  """

  alias OliWeb.Pow.SessionUtils

  import Plug.Conn
  require Logger

  @threshold Application.compile_env(:oli, OliWeb.Endpoint, [])
             |> Keyword.get(:http, [])
             |> Keyword.get(:protocol_options, [])
             |> Keyword.get(:max_header_value_length)

  def init(opts) do
    # Allow passing a custom capture module for testing
    Keyword.put_new(opts, :capture_module, Oli.Utils.Appsignal)
  end

  def call(conn, opts) do
    conn
    |> maybe_log_header_size(Keyword.put(opts, :type, :request))
    |> register_before_send(&maybe_log_header_size(&1, Keyword.put(opts, :type, :response)))
  end

  defp maybe_log_header_size(conn, opts) do
    header_size =
      SessionUtils.calculate_headers_size(
        if opts[:type] == :request, do: conn.req_headers, else: conn.resp_headers
      )

    if header_size > @threshold, do: log_to_analytics(header_size, conn, opts)

    conn
  end

  defp log_to_analytics(size, conn, opts) do
    request_type = Atom.to_string(opts[:type]) |> String.capitalize()

    additional_data = %{
      type: request_type,
      size: size,
      headers: if(request_type == "Request", do: conn.req_headers, else: conn.resp_headers),
      path: conn.request_path,
      method: conn.method,
      user_agent: get_req_header(conn, "user-agent") |> List.first() || "",
      ip: conn.remote_ip |> :inet.ntoa() |> to_string()
    }

    message =
      "#{request_type} headers size (#{size} bytes) exceeds the threshold of #{@threshold} bytes."

    capture_module = opts[:capture_module]
    capture_module.capture_error("#{message}: #{inspect(additional_data)}")

    Logger.warning("#{message}: #{inspect(additional_data)}")
  end
end
