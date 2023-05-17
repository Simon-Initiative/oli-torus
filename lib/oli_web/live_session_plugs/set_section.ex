defmodule Oli.LiveSessionPlugs.SetSection do
  import Phoenix.LiveView, only: [push_redirect: 2, put_flash: 3]
  import Phoenix.Component, only: [assign: 2]

  alias Oli.Delivery.Sections
  alias OliWeb.Router.Helpers, as: Routes

  def on_mount(:default, %{"section_slug" => section_slug}, _session, socket) do
    case Sections.get_section_by_slug(section_slug) do
      # redirect
      nil ->
        {:halt,
         socket
         |> put_flash(:error, "Section not found")
         |> push_redirect(to: Routes.delivery_path(OliWeb.Endpoint, :open_and_free_index))}

      section ->
        {:cont, assign(socket, section: section)}
    end
  end

  def on_mount(:default, _params, _session, socket) do
    {:cont, socket}
  end
end
