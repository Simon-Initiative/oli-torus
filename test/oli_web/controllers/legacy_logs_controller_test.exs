defmodule OliWeb.LegacyLogsControllerTest do
  use OliWeb.ConnCase

  test "returns a plain-text acknowledgement", %{conn: conn} do
    log = """
    <?xml version="1.0" encoding="UTF-8"?>
    <log_action
      action_id="SUBMIT_ATTEMPT"
      external_object_id="#{Ecto.UUID.generate()}"
      info_type="externalId"
    >
      0
    </log_action>
    """

    conn =
      conn
      |> put_req_header("content-type", "text/xml")
      |> post("/jcourse/dashboard/log/server", log)

    assert conn.status == 200
    assert conn.resp_body == "status=success"
    assert get_resp_header(conn, "content-type") == ["text/plain; charset=utf-8"]
  end
end
