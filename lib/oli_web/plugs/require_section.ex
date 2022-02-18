defmodule Oli.Plugs.RequireSection do
  import Plug.Conn
  import Phoenix.Controller

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionInvites
  alias OliWeb.Router.Helpers, as: Routes

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.path_params do
      %{"section_slug" => section_slug} ->
        case Sections.get_section_by_slug(section_slug) do
          nil ->
            section_not_found(conn)

          section ->
            conn
            |> assign(:section, section)
            |> put_session(:section_slug, section_slug)
        end

      %{"section_invite_slug" => section_invite_slug} ->
        section_invite = SectionInvites.get_section_invite(section_invite_slug)

        unless SectionInvites.link_expired?(section_invite) do
          case SectionInvites.get_section_by_invite_slug(section_invite_slug) do
            nil ->
              section_not_found(conn)

            section ->
              conn
              |> assign(:section, section)
          end
        else
          conn
          |> redirect(
            to: Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.InvalidSectionInviteView)
          )
          |> halt()
        end

      _ ->
        section_not_found(conn)
    end
  end

  defp section_not_found(conn) do
    conn
    |> put_view(OliWeb.DeliveryView)
    |> put_status(404)
    |> render("section_not_found.html")
    |> halt()
  end
end
