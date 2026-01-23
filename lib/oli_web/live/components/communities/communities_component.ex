defmodule OliWeb.Live.Components.Communities.CommunitiesComponent do
  @moduledoc """
  LiveComponent for managing community associations in admin user/author detail views.

  This component provides community selection functionality for users and authors.
  Unlike TagsComponent, this component does NOT allow creating new communities -
  it only allows selecting from existing ones.

  The component has three states:
  - `disabled_edit == true`: Readonly mode with gray background and comma-separated links
  - `disabled_edit == false && community_edit_mode == false`: Shows colored tags (clickable to open editor)
  - `disabled_edit == false && community_edit_mode == true`: Full edit UI with tags, X buttons, search, dropdown
  """

  use OliWeb, :live_component

  alias Oli.Groups
  alias OliWeb.Router.Helpers, as: Routes

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:community_edit_mode, false)
     |> assign(:available_communities, [])
     |> assign(:selected_community_ids, [])
     |> assign(:error, nil)
     |> assign(:input_value, "")
     |> assign(:initialized, false)}
  end

  @impl true
  def update(assigns, socket) do
    disabled_edit = Map.get(assigns, :disabled_edit, true)

    # Only initialize current_communities from assigns on first mount
    # After that, ALWAYS keep the component's local state to preserve add/remove changes
    current_communities =
      if not socket.assigns[:initialized] do
        assigns.current_communities || []
      else
        socket.assigns.current_communities
      end

    # Reset community_edit_mode when disabled_edit becomes true
    community_edit_mode =
      if disabled_edit do
        false
      else
        socket.assigns[:community_edit_mode] || false
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:current_communities, current_communities)
     |> assign(:disabled_edit, disabled_edit)
     |> assign(:community_edit_mode, community_edit_mode)
     |> assign(:selected_community_ids, Enum.map(current_communities, & &1.id))
     |> assign(:initialized, true)}
  end

  @impl true
  def handle_event("toggle_edit", _params, socket) do
    new_community_edit_mode = !socket.assigns.community_edit_mode

    socket =
      if new_community_edit_mode do
        socket
        |> assign(:community_edit_mode, true)
        |> load_available_communities()
        |> push_event("focus_input", %{input_id: "community-input-#{socket.assigns.id}"})
      else
        socket
        |> assign(:community_edit_mode, false)
        |> assign(:input_value, "")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("exit_community_edit_mode", _params, socket) do
    {:noreply,
     socket
     |> assign(:community_edit_mode, false)
     |> assign(:input_value, "")}
  end

  @impl true
  def handle_event("add_community", %{"community_id" => community_id}, socket) do
    community_id = String.to_integer(community_id)
    entity_type = socket.assigns.entity_type
    entity_id = socket.assigns.entity_id

    case associate_community(entity_type, entity_id, community_id) do
      {:ok, _} ->
        case Enum.find(socket.assigns.available_communities, &(&1.id == community_id)) do
          nil ->
            {:noreply, assign(socket, :error, "Community not found")}

          community_to_add ->
            updated_current_communities =
              [community_to_add | socket.assigns.current_communities]
              |> Enum.sort_by(& &1.name, :asc)

            updated_available_communities =
              Enum.reject(socket.assigns.available_communities, &(&1.id == community_id))

            {:noreply,
             socket
             |> assign(:current_communities, updated_current_communities)
             |> assign(:available_communities, updated_available_communities)
             |> assign(:selected_community_ids, Enum.map(updated_current_communities, & &1.id))
             |> assign(:error, nil)
             |> assign(:input_value, "")
             |> push_event("focus_input", %{input_id: "community-input-#{socket.assigns.id}"})}
        end

      {:error, _} ->
        {:noreply, assign(socket, :error, "Failed to add community")}
    end
  end

  @impl true
  def handle_event("remove_community", %{"community_id" => community_id}, socket) do
    community_id = String.to_integer(community_id)
    entity_type = socket.assigns.entity_type
    entity_id = socket.assigns.entity_id

    case remove_community(entity_type, entity_id, community_id) do
      {:ok, _} ->
        removed_community =
          Enum.find(socket.assigns.current_communities, &(&1.id == community_id))

        updated_current_communities =
          Enum.reject(socket.assigns.current_communities, &(&1.id == community_id))

        updated_available_communities =
          if removed_community && removed_community not in socket.assigns.available_communities do
            [removed_community | socket.assigns.available_communities]
            |> Enum.sort_by(& &1.name, :asc)
          else
            socket.assigns.available_communities
          end

        {:noreply,
         socket
         |> assign(:current_communities, updated_current_communities)
         |> assign(:available_communities, updated_available_communities)
         |> assign(:selected_community_ids, Enum.map(updated_current_communities, & &1.id))
         |> assign(:error, nil)
         |> push_event("focus_input", %{input_id: "community-input-#{socket.assigns.id}"})}

      {:error, _} ->
        {:noreply, assign(socket, :error, "Failed to remove community")}
    end
  end

  @impl true
  def handle_event("search_communities", params, socket) do
    search = Map.get(params, "value") || Map.get(params, "search") || ""

    {:noreply,
     socket
     |> assign(:input_value, search)
     |> load_available_communities(search)}
  end

  @impl true
  def handle_event("handle_keydown", %{"key" => "Escape"}, socket) do
    {:noreply,
     socket
     |> assign(:community_edit_mode, false)
     |> assign(:input_value, "")}
  end

  @impl true
  def handle_event("handle_keydown", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :communities_count, length(assigns.current_communities || []))

    ~H"""
    <div
      class="relative w-full h-full"
      id={"communities-container-#{@id}"}
    >
      <%= cond do %>
        <% @disabled_edit -> %>
          <!-- Disabled/Readonly mode - gray background with comma-separated links -->
          <div class="form-control bg-[var(--color-gray-100)]">
            <%= if Enum.empty?(@current_communities) do %>
              <span class="text-muted">None</span>
            <% else %>
              <%= for {community, index} <- Enum.with_index(@current_communities) do %>
                <.link
                  href={Routes.live_path(OliWeb.Endpoint, OliWeb.CommunityLive.ShowView, community.id)}
                  class="text-primary hover:underline"
                >
                  {community.name}
                </.link><%= if index < @communities_count - 1 do %><span>, </span><% end %>
              <% end %>
            <% end %>
          </div>

        <% @community_edit_mode -> %>
          <!-- Edit mode open - tags with X buttons, search input, dropdown -->
          <div class="z-20" phx-click-away="exit_community_edit_mode" phx-target={@myself}>
            <div class="relative w-full h-full">
              <div class="bg-Specially-Tokens-Fill-fill-input border border-Table-table-border rounded-[3px] text-sm w-full h-full min-h-[100px] flex flex-col items-center gap-1 p-2">
                <%= for community <- @current_communities do %>
                  <span
                    role="selected community"
                    class={"px-3 py-1 mr-auto rounded-full text-sm font-semibold shadow-sm flex items-center gap-2 #{get_community_pill_classes(community.name)}"}
                  >
                    <span>{community.name}</span>
                    <button
                      type="button"
                      phx-click="remove_community"
                      phx-value-community_id={community.id}
                      phx-target={@myself}
                      class="ml-auto text-sm hover:opacity-70 transition-opacity duration-200"
                    >
                      X
                    </button>
                  </span>
                <% end %>

                <div class="flex-1 min-w-[180px]">
                  <input
                    type="text"
                    phx-keyup="search_communities"
                    phx-keydown="handle_keydown"
                    phx-target={@myself}
                    value={@input_value}
                    placeholder="Search communities..."
                    class="w-full px-3 border-0 outline-none text-[#757682] font-semibold focus:bg-transparent focus:ring-0 focus:border-transparent"
                    id={"community-input-#{@id}"}
                  />
                </div>
              </div>

              <div class="absolute top-[calc(100%+1px)] left-0 w-full z-[5] bg-Table-table-row-1 border border-Table-table-border rounded-[3px] max-h-60 overflow-y-auto shadow-xl">
                <%= if Enum.any?(@available_communities, fn community -> community.id not in @selected_community_ids end) do %>
                  <div class="p-3 space-y-2">
                    <div class="text-Text-text-low text-xs font-semibold mb-2">
                      Select a community
                    </div>
                    <div class="flex flex-col gap-2">
                      <%= for community <- @available_communities do %>
                        <%= if community.id not in @selected_community_ids do %>
                          <button
                            type="button"
                            phx-click="add_community"
                            phx-value-community_id={community.id}
                            phx-target={@myself}
                            class={"px-3 py-1 mr-auto rounded-full text-sm font-semibold shadow-sm transition-colors hover:opacity-80 #{get_community_pill_classes(community.name)}"}
                          >
                            {community.name}
                          </button>
                        <% end %>
                      <% end %>
                    </div>
                  </div>
                <% else %>
                  <div class="p-3">
                    <div class="text-Text-text-low text-xs font-semibold">
                      No communities available
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>

        <% true -> %>
          <!-- Display mode (edit enabled but not open) - clickable colored tags -->
          <div
            class="cursor-pointer w-full min-h-[38px] flex items-start p-2 border border-Table-table-border rounded-[3px] hover:border-Border-border-active hover:bg-Table-table-hover focus:border focus:border-Border-border-active focus:bg-Table-table-hover focus:outline-none"
            phx-click="toggle_edit"
            phx-target={@myself}
            tabindex="0"
          >
            <%= if length(@current_communities) > 0 do %>
              <div class="flex flex-wrap gap-1">
                <%= for community <- @current_communities do %>
                  <span
                    role="selected community"
                    class={"px-3 py-1 rounded-full text-sm font-semibold shadow-sm #{get_community_pill_classes(community.name)}"}
                  >
                    {community.name}
                  </span>
                <% end %>
              </div>
            <% else %>
              <div class="text-Text-text-low text-sm">
                Click to add communities...
              </div>
            <% end %>
          </div>
      <% end %>

      <%= if @error do %>
        <div class="text-red-500 text-xs mt-1">
          {@error}
        </div>
      <% end %>
    </div>
    """
  end

  def get_community_pill_classes(community_name) do
    color_combinations = [
      "bg-Fill-Accent-fill-accent-purple text-Text-text-accent-purple",
      "bg-Fill-Accent-fill-accent-blue text-Text-text-accent-blue",
      "bg-Fill-Accent-fill-accent-orange text-Text-text-accent-orange",
      "bg-Fill-Accent-fill-accent-teal text-Text-text-accent-teal"
    ]

    hash = :erlang.phash2(community_name, 4)
    "#{Enum.at(color_combinations, hash)} shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)]"
  end

  # Private functions

  defp load_available_communities(socket, search \\ "") do
    try do
      communities =
        if search == "" do
          Groups.list_communities()
        else
          Groups.list_communities()
          |> Enum.filter(fn community ->
            String.contains?(String.downcase(community.name), String.downcase(search))
          end)
        end

      assign(socket, :available_communities, communities)
    rescue
      _ ->
        assign(socket, :error, "Failed to load communities")
    end
  end

  defp associate_community(:user, user_id, community_id) do
    Groups.create_community_account(%{user_id: user_id, community_id: community_id})
  end

  defp associate_community(:author, author_id, community_id) do
    Groups.create_community_account(%{author_id: author_id, community_id: community_id})
  end

  defp remove_community(:user, user_id, community_id) do
    Groups.delete_community_account(%{user_id: user_id, community_id: community_id})
  end

  defp remove_community(:author, author_id, community_id) do
    Groups.delete_community_account(%{author_id: author_id, community_id: community_id})
  end
end
