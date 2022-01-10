defmodule OliWeb.HealthController do
  use OliWeb, :controller

  action_fallback OliWeb.FallbackController

  def index(conn, _params) do
    with {:ok, _} <- Ecto.Adapters.SQL.query(Oli.Repo, "select 1", []) do
      render(conn, "index.json", status: "Ayup!")
    end
  end
end
