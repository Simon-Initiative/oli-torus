defmodule OliWeb.LiveSessionPlugs.RequireInstructorPreview do
  use OliWeb, :verified_routes

  import Phoenix.LiveView, only: [redirect: 2]

  alias Oli.Accounts
  alias Oli.Delivery.Sections

  def on_mount(:default, %{"section_slug" => section_slug} = params, _session, socket) do
    if socket.assigns[:preview_mode] == true and
         authorized?(socket.assigns, section_slug) do
      {:cont, socket}
    else
      {:halt, redirect(socket, to: fallback_path(section_slug, params))}
    end
  end

  def on_mount(:default, _params, _session, socket), do: {:cont, socket}

  defp authorized?(assigns, section_slug) do
    Sections.is_instructor?(assigns[:current_user], section_slug) or
      Accounts.is_admin?(assigns[:current_author])
  end

  defp fallback_path(section_slug, %{"revision_slug" => revision_slug}),
    do: ~p"/sections/#{section_slug}/prologue/#{revision_slug}"

  defp fallback_path(section_slug, _params), do: ~p"/sections/#{section_slug}"
end
