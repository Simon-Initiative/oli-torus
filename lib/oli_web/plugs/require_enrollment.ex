defmodule OliWeb.Plugs.RequireEnrollment do
  use OliWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Oli.Delivery.Sections

  @suspended_message "Your access to this course has been suspended. Please contact your instructor."

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns[:current_user]
    section = conn.assigns[:section]
    is_admin = conn.assigns[:is_admin]

    cond do
      is_admin ->
        conn

      Sections.is_enrolled?(user.id, section.slug) ->
        conn

      !section.requires_enrollment ->
        # if section does not require enrollment this plug should do nothing
        conn

      section.registration_open ->
        case Sections.get_enrollment(section.slug, user.id, filter_by_status: false) do
          %_{status: :suspended} ->
            conn
            |> put_flash(:error, @suspended_message)
            |> redirect(to: ~p"/users/log_in?request_path=%2Fsections%2F#{section.slug}")
            |> halt()

          _ ->
            conn
            |> redirect(to: ~p"/sections/#{section.slug}/enroll")
            |> halt()
        end

      true ->
        conn
        |> put_view(OliWeb.PageDeliveryView)
        |> render("not_authorized.html")
        |> halt()
    end
  end
end
