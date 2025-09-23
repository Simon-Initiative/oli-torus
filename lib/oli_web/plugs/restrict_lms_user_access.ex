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

  alias Oli.Delivery.Sections

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns[:current_user]
    section = conn.assigns[:section]

    # Check if user is LMS (independent_learner = false)
    is_lms_user = user && !user.independent_learner

    # Check if section is not LMS (lti_1p3_deployment_id = nil)
    is_non_lms_section = section && is_nil(section.lti_1p3_deployment_id)

    if is_lms_user && is_non_lms_section do
      conn
      |> put_flash(:error, "LMS users cannot access non-LMS sections directly.")
      |> redirect(to: ~p"/lms_user_instructions")
      |> halt()
    else
      conn
    end
  end
end
