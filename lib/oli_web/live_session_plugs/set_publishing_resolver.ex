defmodule OliWeb.LiveSessionPlugs.SetPublishingResolver do
  use OliWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2]

  def on_mount(:authoring, _params, _session, socket) do
    {:cont, assign(socket, publishing_resolver: Oli.Publishing.AuthoringResolver)}
  end

  def on_mount(:delivery, _params, _session, socket) do
    {:cont, assign(socket, publishing_resolver: Oli.Publishing.DeliveryResolver)}
  end
end
