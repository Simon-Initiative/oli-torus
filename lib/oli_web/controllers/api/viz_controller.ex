defmodule OliWeb.Api.VizController do
  use OliWeb, :controller

  import Oli.HTTP

  def index(conn, _params) do

    # Make an HTTP GET request to http://localhost:8080/api/viz
    {:ok, %{status_code: 200, body: body}} =
      http().get("http://localhost:8080/api/viz")

    json conn, Jason.decode!(body)
  end

  def show(conn, %{"section_id" => section_id, "analytic_id" => analytic_id}) do

    # Make an HTTP GET request to http://localhost:8080/api/viz/#{section_id}/#{analytic_id}
    {:ok, %{status_code: 200, body: body}} =
      http().get("http://localhost:8080/api/viz/#{analytic_id}/#{section_id}")

    json conn, Jason.decode!(body)
  end
end
