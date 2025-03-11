defmodule Oli.Plugs.RequireSection do
  use OliWeb, :verified_routes

  import Phoenix.Controller
  import Plug.Conn

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.{Section, SectionInvite, SectionInvites}
  alias Oli.Repo

  def init(opts), do: opts

  def call(%{path_params: %{"section_slug" => section_slug}} = conn, _opts) do
    case Sections.get_section_by_slug(section_slug) do
      nil ->
        section_not_found(conn)

      section ->
        conn
        |> section_assigns(section)
        |> put_session(:section_slug, section_slug)
    end
  end

  def call(%{path_params: %{"section_invite_slug" => section_invite_slug}} = conn, _opts) do
    with sec_inv = %SectionInvite{} <- SectionInvites.get_section_invite(section_invite_slug),
         false <- SectionInvites.link_expired?(sec_inv) do
      case SectionInvites.get_section_by_invite_slug(section_invite_slug) do
        nil -> section_not_found(conn)
        section -> section_assigns(conn, section)
      end
    else
      _ -> redirect(conn, to: ~p"/sections/join/invalid") |> halt()
    end
  end

  defp section_assigns(conn, section) do
    section = Repo.preload(section, [:brand, lti_1p3_deployment: [institution: [:default_brand]]])

    conn
    |> assign(:section, section)
    |> assign(:skip_email_verification, skip_email_verification?(section))
    |> assign(:brand, Oli.Branding.get_section_brand(section))
  end

  defp skip_email_verification?(%Section{skip_email_verification: true}), do: true
  defp skip_email_verification?(_section), do: false

  defp section_not_found(conn) do
    conn
    |> put_view(OliWeb.DeliveryView)
    |> put_status(404)
    |> render("section_not_found.html")
    |> halt()
  end
end
