defmodule OliWeb.LegacyLogsController do
  use OliWeb, :controller

  def process(conn, _params) do

    conn
    |> put_resp_content_type("text/xml")
    |> send_resp(200, "status=success")

  end
end
