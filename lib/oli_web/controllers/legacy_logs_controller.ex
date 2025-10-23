defmodule OliWeb.LegacyLogsController do
  use OliWeb, :controller

  alias Oli.Delivery.CustomLogs.LegacyLogs

  def process(conn, _params) do
    doc =
      case Map.get(conn.assigns, :raw_body) do
        nil ->
          {:ok, raw_body, _conn} = Plug.Conn.read_body(conn, length: 20_000_000)
          raw_body

        raw_body ->
          raw_body
      end

    case LegacyLogs.create(doc, host_name()) do
      :ok ->
        conn
        |> put_resp_content_type("text/xml")
        |> send_resp(200, "status=success")

      _ ->
        conn
        |> put_resp_content_type("text/xml")
        |> send_resp(500, "status=error")
    end
  end

  defp host_name() do
    Application.get_env(:oli, OliWeb.Endpoint)
    |> Keyword.get(:url)
    |> Keyword.get(:host)
  end
end
