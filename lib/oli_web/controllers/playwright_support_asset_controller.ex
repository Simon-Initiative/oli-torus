defmodule OliWeb.PlaywrightSupportAssetController do
  use OliWeb, :controller

  @moduledoc """
  Serves deterministic support assets used by Playwright automation scenarios.

  This controller handles both:
  - the embedded runtime stub needed by delivery automation when legacy
    superactivity assets are unavailable locally
  - small fixture files that live alongside the Playwright specs so activity
    tests can exercise resource-loading behavior without depending on the media
    library or object storage
  """

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
