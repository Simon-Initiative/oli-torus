defmodule OliWeb.LiveSessionPlugs.SetSidebar do
  @moduledoc """
  This live session plug sets the hooks needed to handle the sidebar state (expanded or collapsed)
  by reading the `sidebar_expanded` parameter from the URL and setting it in the socket assigns.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [attach_hook: 4, connected?: 1]
  import Oli.Utils, only: [string_to_boolean: 1]

  alias Oli.Resources.Collaboration.CollabSpaceConfig
  alias Oli.Resources.Collaboration
  alias Oli.Publishing.{DeliveryResolver}

  def on_mount(:default, _params, session, socket) do
    socket =
      socket
      |> assign_notes_and_discussions_enabled(session["section_slug"])
      |> assign(sidebar_expanded: session["sidebar_expanded"])
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
    previous_workspace = process_url(previous_url)
    current_workspace = process_url(current_url)

    previous_workspace == current_workspace
  end

  defp process_url(url) do
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

  defp assign_notes_and_discussions_enabled(socket, nil),
    do: assign(socket, notes_enabled: false, discussions_enabled: false)

  defp assign_notes_and_discussions_enabled(socket, section_slug) do
    {collab_space_pages_count, _pages_count} =
      Collaboration.count_collab_spaces_enabled_in_pages_for_section(section_slug)

    notes_enabled = collab_space_pages_count > 0

    %{slug: revision_slug} = DeliveryResolver.root_container(section_slug)

    discussions_enabled =
      case Collaboration.get_collab_space_config_for_page_in_section(
             revision_slug,
             section_slug
           ) do
        {:ok, %CollabSpaceConfig{status: :enabled}} ->
          true

        _ ->
          false
      end

    assign(socket, notes_enabled: notes_enabled, discussions_enabled: discussions_enabled)
  end
end
