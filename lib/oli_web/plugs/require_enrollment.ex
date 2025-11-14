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
    enrollment = Sections.get_enrollment(section.slug, user.id, filter_by_status: false)

    cond do
      is_admin ->
        conn

      enrolled?(enrollment, section) ->
        conn

      !section.requires_enrollment ->
        # if section does not require enrollment this plug should do nothing
        conn

      section.registration_open && suspended?(enrollment) ->
        conn
        |> put_flash(:error, @suspended_message)
        |> redirect(to: ~p"/users/log_in?request_path=%2Fsections%2F#{section.slug}")
        |> halt()

      section.registration_open ->
        conn
        |> redirect(to: ~p"/sections/#{section.slug}/enroll")
        |> halt()

      true ->
        conn
        |> put_view(OliWeb.PageDeliveryView)
        |> render("not_authorized.html")
        |> halt()
    end
  end

  defp enrolled?(%{status: :enrolled}, %{status: :active}), do: true
  defp enrolled?(_, _), do: false

  defp suspended?(%{status: :suspended}), do: true
  defp suspended?(_), do: false
end
