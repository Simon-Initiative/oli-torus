defmodule Oli.Plugs.RequireSection do
  use OliWeb, :verified_routes

  import Phoenix.Controller
  import Plug.Conn

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionInvite
  alias Oli.Delivery.Sections.SectionInvites
  alias Oli.Repo

  def init(opts), do: opts

  def call(%{path_params: %{"section_slug" => section_slug}} = conn, _opts) do
    case Sections.get_section_by_slug(section_slug) do
      nil ->
        section_not_found(conn)

      section ->
        conn
        |> assign_section_and_brand(section)
        |> put_session(:section_slug, section_slug)
    end
  end

  def call(%{path_params: %{"section_invite_slug" => section_invite_slug}} = conn, _opts) do
    with sec_inv = %SectionInvite{} <- SectionInvites.get_section_invite(section_invite_slug),
         false <- SectionInvites.link_expired?(sec_inv) do
      case SectionInvites.get_section_by_invite_slug(section_invite_slug) do
        nil -> section_not_found(conn)
        section -> assign_section_and_brand(conn, section)
      end
    else
      _ -> redirect(conn, to: ~p"/sections/join/invalid") |> halt()
    end
  end

  defp assign_section_and_brand(conn, section) do
    section = Repo.preload(section, [:brand, lti_1p3_deployment: [institution: [:default_brand]]])

    conn
    |> assign(:section, section)
    |> assign(:brand, Oli.Branding.get_section_brand(section))
  end

  defp section_not_found(conn) do
    conn
    |> put_view(OliWeb.DeliveryView)
    |> put_status(404)
    |> render("section_not_found.html")
    |> halt()
  end
end
