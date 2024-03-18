defmodule OliWeb.LiveSessionPlugs.SetPreviewMode do
  use OliWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2]

  def on_mount(:default, _params, _session, socket) do
    {:cont, assign(socket, preview_mode: socket.assigns[:live_action] == :preview)}
  end
end
