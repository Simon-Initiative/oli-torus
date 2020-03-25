defmodule OliWeb.DeliveryController do
  use OliWeb, :controller

  alias Oli.Lti

  def index(conn, _params) do
    user = conn.assigns.current_user

    case Lti.parse_lti_role(user.roles) do
      :administrator ->
        render(conn, "instructor_view.html")
      :instructor ->
        render(conn, "instructor_view.html")
      :student ->
        render(conn, "student_view.html")
    end
  end

  def link_account(conn, _params) do
    actions = %{
      google: Routes.auth_path(conn, :request, "google", type: "link-account"),
      facebook: Routes.auth_path(conn, :request, "facebook", type: "link-account"),
      identity: Routes.auth_path(conn, :identity_callback, type: "link-account"),
      cancel: Routes.delivery_path(conn, :index),
    }

    assigns = conn.assigns
    |> Map.put(:title, "Link Existing Account")
    |> Map.put(:actions, actions)
    |> Map.put(:show_remember_password, false)
    |> Map.put(:show_cancel, true)

    conn
    |> put_view(OliWeb.AuthView)
    |> render("signin.html", assigns)
  end

end
