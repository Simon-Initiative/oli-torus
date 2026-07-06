defmodule OliWeb.PlaywrightEmbeddedRuntimeController do
  use OliWeb, :controller

  @moduledoc """
  Serves the deterministic embedded runtime stub used by Playwright delivery tests.

  This handles the automation-only case where embedded activities need to launch a
  working iframe runtime, but the legacy superactivity assets are not available
  from object storage or a proxied external host in the local test environment.
  """

  def show(conn, _params) do
    conn
    |> put_resp_content_type("text/html")
    |> send_file(200, stub_path())
  end

  defp stub_path do
    Path.expand("../../../test/support/embedded_runtime_stub/index.html", __DIR__)
  end
end
