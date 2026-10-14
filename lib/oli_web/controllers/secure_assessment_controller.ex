defmodule OliWeb.SecureAssessmentController do
  use OliWeb, :controller

  @doc "Shows a confined denial without redirecting through course delivery."
  def restricted(conn, _params) do
    OliWeb.Plugs.SecureAssessment.deny(conn, :secure_resource_mismatch)
  end

  @doc "Ends only this browser's authentication, without modifying assessment attempts."
  def exit(conn, _params) do
    conn
    |> OliWeb.UserAuth.clear_all_session_data()
    |> put_resp_header("cache-control", "no-store")
    |> redirect(to: "/secure-assessment/signed-out")
  end

  @doc "Shows a minimal signed-out page, without course navigation or return targets."
  def signed_out(conn, _params) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> html(
      "<!doctype html><html lang=\"en\"><head><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>Assessment session ended</title></head><body><main><h1>Assessment session ended</h1><p>You may close this browser. To resume an unfinished assessment, launch it securely again from your learning platform.</p></main></body></html>"
    )
  end
end
