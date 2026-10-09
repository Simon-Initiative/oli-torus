defmodule OliWeb.HealthController do
  use OliWeb, :controller

  @doc "Returns local startup/liveness without querying dependencies."
  def index(conn, _params) do
    {code, status} =
      case Oli.Health.live?() do
        true -> {200, "Ayup!"}
        false -> {503, "starting"}
      end

    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_status(code)
    |> render("index.json", status: status)
  end
end
