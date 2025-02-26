defmodule OliWeb.Plugs.RequireEnrollment do
  use OliWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Oli.Delivery.Sections

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

      section.registration_open ->
        conn
        |> redirect(to: ~p"/sections/#{section.slug}/enroll")
        |> Plug.Conn.halt()

      true ->
        conn
        |> put_view(OliWeb.PageDeliveryView)
        |> render("not_authorized.html")
        |> halt()
    end
  end
end
