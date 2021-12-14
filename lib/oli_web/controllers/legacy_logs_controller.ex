defmodule OliWeb.LegacyLogsController do
  use OliWeb, :controller

  import SweetXml

  def process(conn, _params) do

    doc = Map.get(conn.assigns, :raw_body)
    result = doc |> xpath(~x"//*/@external_object_id")
    IO.inspect result

    conn
    |> put_resp_content_type("text/xml")
    |> send_resp(200, "status=success")

  end
end
