defmodule OliWeb.PlaywrightSupportAssetController do
  use OliWeb, :controller

  @moduledoc """
  Serves deterministic support assets used by Playwright automation scenarios.

  This controller handles:
  - the embedded runtime stub needed by delivery automation when legacy
    superactivity assets are unavailable locally
  - small fixture files that live alongside the Playwright specs so activity
    tests can exercise resource-loading behavior without depending on the media
    library or object storage
  - private test assets (course archives, answer keys) proxied from the
    Playwright assets bucket; these require the scenario token because their
    contents must not be publicly reachable
  """

  alias Oli.Scenarios.PlaywrightAssetStorage
  alias OliWeb.PlaywrightAuth

  @allowed_files %{
    "image_coding_sample.png" => "image/png",
    "image_coding_table.csv" => "text/csv"
  }

  def embedded_runtime(conn, _params) do
    conn
    |> put_resp_content_type("text/html")
    |> send_file(200, embedded_runtime_path())
  end

  def support_asset(conn, %{"filename" => filename}) do
    case Map.fetch(@allowed_files, filename) do
      {:ok, mime} ->
        conn
        |> put_resp_content_type(mime)
        |> send_file(200, asset_path(filename))

      :error ->
        send_resp(conn, 404, "Not found")
    end
  end

  def private_asset(conn, %{"path" => path_parts}) do
    with :ok <- PlaywrightAuth.authorize(conn),
         key <- Enum.join(path_parts, "/"),
         {:ok, %{body: body, content_type: content_type}} <-
           PlaywrightAssetStorage.get_object(key) do
      conn
      |> put_resp_content_type(content_type)
      |> put_resp_header("cache-control", "no-store")
      |> send_resp(200, body)
    else
      {:error, :unauthorized} -> send_resp(conn, 401, "unauthorized")
      {:error, :invalid_key} -> send_resp(conn, 400, "invalid_key")
      {:error, :not_found} -> send_resp(conn, 404, "not_found")
      {:error, _reason} -> send_resp(conn, 500, "asset_fetch_failed")
    end
  end

  defp embedded_runtime_path do
    Path.expand("../../../test/support/embedded_runtime_stub/index.html", __DIR__)
  end

  defp asset_path(filename) do
    Path.expand(
      "../../../assets/automation/tests/torus/student_delivery/support/#{filename}",
      __DIR__
    )
  end
end
