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
  - `actor` — the user or author changing the settings, recorded in the Audit Log
  """

  use OliWeb, :live_component

  alias Oli.Auditing.Context
  alias Oli.Delivery.Sections.Audited, as: SectionsAudited
  alias Oli.Resources.Collaboration.CollabSpaceConfig

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:revert_count, fn -> 0 end)
     |> assign_new(:reverted, fn -> nil end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={"notes-#{@id}"}>
      <section>
        <%!-- A new id after a failed save renders the toggle again from the saved setting --%>
        <div
          id={"#{@id}-toggle-wrapper-#{@revert_count}"}
          phx-mounted={@revert_count > 0 && JS.focus(to: "##{@reverted}")}
          class="inline-flex py-2 mb-2 border-b dark:border-gray-700"
        >
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
    context = Context.for_actor(socket.assigns.actor, source: :ui)

    case socket.assigns.collab_space_pages_count > 0 do
      true ->
        case SectionsAudited.set_section_notes(context, socket.assigns.section, :disabled) do
          {:ok, _count} ->
            send(self(), {:flash, :info, "Notes disabled for all pages"})
            send(self(), {:notes_count_updated, 0})
            {:noreply, assign(socket, :collab_space_pages_count, 0)}

          {:error, _reason} ->
            send(self(), {:flash, :error, "Failed to disable notes"})
            {:noreply, revert(socket, "toggle-notes_checkbox")}
        end

      false ->
        case SectionsAudited.set_section_notes(
               context,
               socket.assigns.section,
               %CollabSpaceConfig{status: :enabled}
             ) do
          {:ok, total_page_count} ->
            send(self(), {:flash, :info, "Notes enabled for all pages"})
            send(self(), {:notes_count_updated, total_page_count})
            {:noreply, assign(socket, :collab_space_pages_count, total_page_count)}

          {:error, _reason} ->
            send(self(), {:flash, :error, "Failed to enable notes"})
            {:noreply, revert(socket, "toggle-notes_checkbox")}
        end
    end
  end

  # Nothing was saved: a new wrapper id renders the toggles again from the saved settings, and
  # focus returns to the control that was used.
  defp revert(socket, control) do
    assign(socket,
      revert_count: socket.assigns.revert_count + 1,
      reverted: "#{socket.assigns.id}-#{control}"
    )
  end
end
