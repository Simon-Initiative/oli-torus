defmodule OliWeb.ReadinessController do
  use OliWeb, :controller

  @doc "Returns bounded readiness, including compiled identity only in Playwright builds."
  def index(conn, _params) do
    {code, status} =
      case Oli.Health.ready?() do
        true -> {200, "ready"}
        false -> {503, "not_ready"}
      end

    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_status(code)
    |> render("index.json", status: status)
  end
end
