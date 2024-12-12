defmodule OliWeb.LiveSessionPlugs.SetAnnotations do
  @moduledoc """
  This live session plug sets the assigns needed to handle the notes and discussion annotations
  """

  import Phoenix.Component, only: [assign: 2]

  alias Oli.Resources.Collaboration.CollabSpaceConfig
  alias Oli.Resources.Collaboration
  alias Oli.Publishing.{DeliveryResolver}

  def on_mount(:default, :not_mounted_at_router, _session, socket) do
    # handle the case where liveview is rendered directly in the template
    {:cont, socket}
  end

  def on_mount(:default, params, _session, socket) do
    section_slug =
      case params do
        %{"section_slug" => section_slug} -> section_slug
        _ -> nil
      end

    socket =
      socket
      |> assign_notes_and_discussions_enabled(section_slug)

    {:cont, socket}
  end

  defp assign_notes_and_discussions_enabled(socket, nil),
    do: assign(socket, notes_enabled: false, discussions_enabled: false)

  defp assign_notes_and_discussions_enabled(socket, section_slug) do
    {collab_space_pages_count, _pages_count} =
      Collaboration.count_collab_spaces_enabled_in_pages_for_section(section_slug)

    notes_enabled = collab_space_pages_count > 0

    discussions_enabled =
      with %{slug: revision_slug} <- DeliveryResolver.root_container(section_slug),
           {:ok, %CollabSpaceConfig{status: :enabled}} <-
             Collaboration.get_collab_space_config_for_page_in_section(
               revision_slug,
               section_slug
             ) do
        true
      else
        _ -> false
      end

    assign(socket, notes_enabled: notes_enabled, discussions_enabled: discussions_enabled)
  end
end
