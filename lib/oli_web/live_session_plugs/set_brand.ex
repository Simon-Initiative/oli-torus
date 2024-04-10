defmodule OliWeb.LiveSessionPlugs.SetBrand do
  use OliWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2]

  alias Oli.Branding

  def on_mount(:default, _params, _session, socket) do
    {:cont, assign(socket, brand: Branding.get_section_brand(socket.assigns[:section]))}
  end
end
