defmodule OliWeb.LiveSessionPlugs.RequireEnrollment do
  import Phoenix.Component, only: [assign: 2]

  alias Oli.Delivery.Sections

  def on_mount(:default, %{"section_slug" => section_slug}, _session, socket) do
    user = socket.assigns.current_user
    is_enrolled = Sections.is_enrolled?(user.id, section_slug)

    {:cont, assign(socket, is_enrolled: is_enrolled)}
  end

  def on_mount(:default, _params, _session, socket) do
    {:cont, socket}
  end
end
