defmodule OliWeb.ConfidenceController do
  use OliWeb, :controller

  @doc "Serves the confidence curve explorer through the admin-authenticated router scope."
  def index(conn, _params) do
    conn
    |> put_resp_content_type("text/html")
    |> put_resp_header("cache-control", "private, no-store")
    |> send_file(200, Application.app_dir(:oli, "priv/admin/confidence.html"))
  end
end
