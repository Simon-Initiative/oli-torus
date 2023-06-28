defmodule OliWeb.LiveSessionPlugs.SetRouteName do
  import Phoenix.Component, only: [assign: 2]

  @moduledoc """
    Adds the route name defined in the metadata map in the live/4 function called from the router
  """
  def on_mount(:default, :not_mounted_at_router, _session, socket) do
    {:cont, socket}
  end

  def on_mount(
        :default,
        _params,
        _session,
        socket
      ),
      do:
        {:cont,
         Phoenix.LiveView.attach_hook(
           socket,
           :save_request_path,
           :handle_params,
           &assign_route_name/3
         )}

  defp assign_route_name(_params, url, socket) do
    %{host: host, path: path} = URI.parse(url)

    case Phoenix.Router.route_info(OliWeb.Router, "GET", path, host) do
      :error ->
        {:cont, socket}

      route_info ->
        {:cont, assign(socket, route_name: Map.get(route_info, :route_name))}
    end
  end
end
