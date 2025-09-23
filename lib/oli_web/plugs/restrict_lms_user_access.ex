defmodule OliWeb.Plugs.RestrictLmsUserAccess do
  @moduledoc """
  Plug that restricts LMS users from accessing non-LMS sections.

  This plug checks if a user is from an LMS (independent_learner = false) and
  if the section they're trying to access is not LMS-based (lti_1p3_deployment_id = nil).
  If both conditions are true, it redirects to an instructions page.
  """

  use OliWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns[:current_user]
    section = conn.assigns[:section]
    request_path = capture_request_path(conn)

    # Check if user is LMS (independent_learner = false)
    is_lms_user = user && !user.independent_learner

    # Check if section is not LMS (lti_1p3_deployment_id = nil)
    is_non_lms_section = section && is_nil(section.lti_1p3_deployment_id)

    if is_lms_user && is_non_lms_section do
      conn
      |> redirect(
        to:
          ~p"/lms_user_instructions?#{[section_title: section.title, request_path: request_path]}"
      )
      |> halt()
    else
      conn
    end
  end

  defp capture_request_path(%{request_path: nil}), do: nil

  defp capture_request_path(conn) do
    build_full_path(conn.request_path, conn.query_string)
  end

  defp build_full_path(path, ""), do: path
  defp build_full_path(path, nil), do: path
  defp build_full_path(path, query), do: path <> "?" <> query
end
