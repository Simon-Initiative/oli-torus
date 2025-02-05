defmodule OliWeb.LiveSessionPlugs.SetSidebar do
  @moduledoc """
  This live session plug sets the hooks needed to handle the sidebar state (expanded or collapsed)
  by reading the `sidebar_expanded` parameter from the URL and setting it in the socket assigns.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [attach_hook: 4, connected?: 1]
  import Oli.Utils, only: [string_to_boolean: 1]

  def on_mount(:default, :not_mounted_at_router, _session, socket) do
    # this case will handle the liveview cases rendered directly in the template
    # for example:
    # <%= live_render(@conn, OliWeb.SystemMessageLive.ShowView) %>
    {:cont, socket}
  end

  def on_mount(:default, params, _session, socket) do
    socket =
      socket
      |> assign(
        sidebar_expanded:
          case Map.get(params, "sidebar_expanded") do
            "false" -> false
            _ -> true
          end
      )
      |> assign(disable_sidebar?: false)
      |> assign(header_enabled?: true)
      |> assign(footer_enabled?: true)

    if connected?(socket) do
      socket =
        attach_hook(socket, :sidebar_hook, :handle_params, fn
          params, uri, socket ->
            sidebar_from_assigns = socket.assigns.sidebar_expanded
            sidebar_from_params = string_to_boolean(params["sidebar_expanded"] || "true")

            socket = assign(socket, uri: uri, sidebar_expanded: sidebar_from_params)

            previous_lv_url = socket.private[:connect_params]["_live_referer"]
            current_lv_url = uri

            has_sidebar_changed = sidebar_from_assigns != sidebar_from_params
            is_same_workspace = is_same_workspace(previous_lv_url, current_lv_url)

            if is_same_workspace and has_sidebar_changed do
              {:halt, socket}
            else
              {:cont, socket}
            end
        end)

      {:cont, socket}
    else
      {:cont, socket}
    end
  end

  defp is_same_workspace(nil, _current_url) do
    true
  end

  defp is_same_workspace(previous_url, current_url) do
    previous_workspace = extract_workspace(previous_url)
    current_workspace = extract_workspace(current_url)

    previous_workspace == current_workspace
  end

  defp extract_workspace(url) do
    URI.parse(url)
    |> Map.get(:path)
    |> String.split("/", trim: true)
    |> case do
      ["workspaces", workspace | _rest] ->
        workspace

      _ ->
        nil
    end
  end
end
