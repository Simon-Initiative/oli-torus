defmodule OliWeb.LiveSessionPlugs.RequireEnrollment do
  use OliWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2]

  alias Oli.Delivery.Sections

  def on_mount(:default, %{"section_slug" => section_slug}, _session, socket) do
    case socket.assigns[:current_user] do
      nil ->
        {:cont, socket}

      user ->
        is_enrolled = Sections.is_enrolled?(user.id, section_slug)

        {:cont, assign(socket, is_enrolled: is_enrolled)}
    end
  end

  def on_mount(:default, _params, _session, socket) do
    {:cont, socket}
  end
end
