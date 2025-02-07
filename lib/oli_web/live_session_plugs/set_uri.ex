defmodule OliWeb.LiveSessionPlugs.SetUri do
  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [attach_hook: 4]

  def on_mount(:default, :not_mounted_at_router, _session, socket) do
    {:cont, socket}
  end

  def on_mount(:default, _params, _session, socket) do
    socket =
      attach_hook(socket, :set_uri, :handle_params, fn _params, uri, socket ->
        socket = assign(socket, uri: uri)
        {:cont, socket}
      end)

    {:cont, socket}
  end
end
