defmodule OliWeb.LiveSessionPlugs.AnalyticsPageView do
  @moduledoc """
  Pushes sanitized context on LiveView route and context changes, including fresh navigation
  mounts. The browser counts a page view only when the route template changes.
  """

  import Phoenix.Component, only: [assign: 3]

  import Phoenix.LiveView,
    only: [attach_hook: 4, connected?: 1, get_connect_params: 1, push_event: 3]

  alias OliWeb.Analytics

  @doc """
  Attaches tracking only to connected, router-mounted views with a covered browser root.

  The analytics subject is captured here, before views slim their assigns. The browser
  reports the context it already holds, so an unchanged context is never pushed again.
  """
  def on_mount(:default, :not_mounted_at_router, _session, socket), do: {:cont, socket}

  def on_mount(:default, _params, _session, socket) do
    case Analytics.enabled?() and connected?(socket) and
           get_connect_params(socket)["analytics_enabled"] == true do
      true ->
        socket =
          socket
          |> assign(:analytics_subject, Analytics.subject(socket.assigns))
          |> assign(:analytics_context, get_connect_params(socket)["analytics_context"])
          |> attach_hook(:analytics_page_view, :handle_params, &track_page/3)

        {:cont, socket}

      false ->
        {:cont, socket}
    end
  end

  defp track_page(_params, url, socket) do
    subject = Analytics.subject(socket.assigns, socket.assigns.analytics_subject)

    case Analytics.page_context(url, subject) do
      nil ->
        {:cont, socket}

      context ->
        reported = Map.new(context, fn {key, value} -> {Atom.to_string(key), value} end)

        case reported == socket.assigns.analytics_context do
          true ->
            {:cont, socket}

          false ->
            {:cont,
             socket
             |> assign(:analytics_context, reported)
             |> push_event("analytics:page_view", context)}
        end
    end
  end
end
