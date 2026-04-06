defmodule OliWeb.Live.Components.Sections.NotesComponent do
  @moduledoc """
  Self-contained LiveComponent for Notes (page-level collaborative spaces) settings.

  Renders:
  - "Enable Notes for all pages in the course" toggle
  - "X pages currently have Notes enabled" status text

  Toggle enables/disables collab_space_config on all page-level section_resources.
  All events handled via `phx-target={@myself}` — no parent event handlers needed.
  Works for both blueprint (product) and enrollable (section) contexts.

  ## Required assigns

  - `id` — unique component ID
  - `section` — a `%Section{}` struct (blueprint or enrollable)
  - `collab_space_pages_count` — number of pages with notes enabled
  - `pages_count` — total number of pages
  """

  use OliWeb, :live_component

  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.CollabSpaceConfig

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={"notes-#{@id}"}>
      <section>
        <div class="inline-flex py-2 mb-2 border-b dark:border-gray-700">
          <span>Enable Notes for all pages in the course</span>
          <.toggle_switch
            id={"#{@id}-toggle-notes"}
            class="ml-4"
            checked={@collab_space_pages_count > 0}
            on_toggle="toggle_notes"
            name="toggle_notes"
            phx_target={@myself}
          />
        </div>
        <div class="text-sm text-gray-600">
          <%= if @pages_count == @collab_space_pages_count and @collab_space_pages_count > 0 do %>
            All {@collab_space_pages_count}
          <% else %>
            {@collab_space_pages_count}
          <% end %>
          {ngettext("page currently has", "pages currently have", @collab_space_pages_count)} Notes enabled.
        </div>
      </section>
    </div>
    """
  end

  # ── Event Handlers ──

  @impl true
  def handle_event("toggle_notes", _params, socket) do
    section = socket.assigns.section

    if socket.assigns.collab_space_pages_count > 0 do
      # Disable all
      Collaboration.disable_all_page_collab_spaces_for_section(section.slug)
      send(self(), {:flash, :info, "Notes disabled for all pages"})
      send(self(), {:notes_count_updated, 0})

      {:noreply, assign(socket, :collab_space_pages_count, 0)}
    else
      # Enable all with default config
      {total_page_count, _section_resources} =
        Collaboration.enable_all_page_collab_spaces_for_section(
          section.slug,
          %CollabSpaceConfig{status: :enabled}
        )

      send(self(), {:flash, :info, "Notes enabled for all pages"})
      send(self(), {:notes_count_updated, total_page_count})

      {:noreply, assign(socket, :collab_space_pages_count, total_page_count)}
    end
  end
end
