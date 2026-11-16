defmodule OliWeb.LiveSessionPlugs.AnalyticsPageView do
  @moduledoc "Pushes sanitized context on LiveView route changes, including fresh navigation mounts."

  import Phoenix.Component, only: [assign: 3]

  import Phoenix.LiveView,
    only: [attach_hook: 4, connected?: 1, get_connect_params: 1, push_event: 3]

  alias OliWeb.Analytics

  @doc "Attaches tracking only to connected, router-mounted views with a covered browser root."
  def on_mount(:default, :not_mounted_at_router, _session, socket), do: {:cont, socket}

  def on_mount(:default, _params, _session, socket) do
    case Analytics.enabled?() and connected?(socket) and
           get_connect_params(socket)["analytics_enabled"] == true do
      true ->
        socket =
          socket
          |> assign(:analytics_page_path, get_connect_params(socket)["analytics_page_path"])
          |> attach_hook(:analytics_page_view, :handle_params, &track_page/3)

        {:cont, socket}

      false ->
        {:cont, socket}
    end
  end

  defp track_page(_params, url, socket) do
    case Analytics.page_context(url, socket.assigns) do
      %{page_path: path} = context when path != socket.assigns.analytics_page_path ->
        {:cont,
         socket
         |> assign(:analytics_page_path, path)
         |> push_event("analytics:page_view", context)}

      _ ->
        {:cont, socket}
    end
  end
end
