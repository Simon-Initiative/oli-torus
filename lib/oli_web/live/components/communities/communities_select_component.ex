defmodule OliWeb.Live.Components.Communities.CommunitiesSelectComponent do
  @moduledoc """
  LiveComponent for managing community associations in admin user detail view.

  This component provides community selection functionality for users.
  Unlike TagsComponent, this component does NOT allow creating new communities -
  it only allows selecting from existing ones.

  Communities can be associated with a user in two ways:
  - Directly: the user is a member of the community
  - Via Institution: the user's LTI institution belongs to the community

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
    institution = Map.get(assigns, :institution)
    user_id = assigns.user_id

    # Only initialize communities on first mount
    # After that, ALWAYS keep the component's local state to preserve add/remove changes
    # Communities are fetched ordered by most recently added first
    direct_communities =
      if not socket.assigns[:initialized] do
        Groups.list_user_direct_communities_ordered(user_id)
      else
        socket.assigns.direct_communities
      end

    # Get communities associated via institution (excluding direct ones)
    institution_communities =
      if not socket.assigns[:initialized] do
        compute_institution_communities(institution, direct_communities)
      else
        socket.assigns.institution_communities
      end

    # Reset community_edit_mode when disabled_edit becomes true
    community_edit_mode =
      if disabled_edit do
        false
      else
        socket.assigns[:community_edit_mode] || false
      end

    all_community_ids =
      Enum.map(direct_communities, & &1.id) ++ Enum.map(institution_communities, & &1.id)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:direct_communities, direct_communities)
     |> assign(:institution_communities, institution_communities)
     |> assign(:disabled_edit, disabled_edit)
     |> assign(:community_edit_mode, community_edit_mode)
     |> assign(:selected_community_ids, all_community_ids)
     |> assign(:initialized, true)}
  end

  defp compute_institution_communities(institution, direct_communities) do
    direct_ids = MapSet.new(Enum.map(direct_communities, & &1.id))

    # Get institution communities ordered by most recently added, excluding direct ones
    Groups.list_institution_communities_ordered(institution)
    |> Enum.reject(fn community -> MapSet.member?(direct_ids, community.id) end)
  end

  @impl true
  def handle_event("toggle_edit", _params, socket) do
    new_community_edit_mode = !socket.assigns.community_edit_mode

    socket =
      if new_community_edit_mode do
        socket
        |> assign(:community_edit_mode, true)
        |> load_available_communities()
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
  def handle_event("add_community", %{"community_id" => community_id_str}, socket) do
    case Integer.parse(community_id_str) do
      {community_id, ""} ->
        handle_add_community(community_id, socket)

      _ ->
        {:noreply, assign(socket, :error, "Invalid community ID")}
    end
  end

  @impl true
  def handle_event("remove_community", %{"community_id" => community_id_str}, socket) do
    case Integer.parse(community_id_str) do
      {community_id, ""} ->
        handle_remove_community(community_id, socket)

      _ ->
        {:noreply, assign(socket, :error, "Invalid community ID")}
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
  def handle_event("handle_container_keydown", %{"key" => key}, socket)
      when key in ["Enter", " "] do
    handle_event("toggle_edit", %{}, socket)
  end

  @impl true
  def handle_event("handle_container_keydown", _params, socket) do
    {:noreply, socket}
  end

  defp handle_add_community(community_id, socket) do
    user_id = socket.assigns.user_id

    case Groups.create_community_account(%{user_id: user_id, community_id: community_id}) do
      {:ok, _} ->
        case Enum.find(socket.assigns.available_communities, &(&1.id == community_id)) do
          nil ->
            {:noreply, assign(socket, :error, "Community not found")}

          community_to_add ->
            # Prepend to beginning (most recently added first)
            updated_direct_communities =
              [community_to_add | socket.assigns.direct_communities]

            updated_available_communities =
              Enum.reject(socket.assigns.available_communities, &(&1.id == community_id))

            # Remove from institution_communities if it was there (now it's direct)
            updated_institution_communities =
              Enum.reject(socket.assigns.institution_communities, &(&1.id == community_id))

            updated_selected_ids =
              Enum.map(updated_direct_communities, & &1.id) ++
                Enum.map(updated_institution_communities, & &1.id)

            {:noreply,
             socket
             |> assign(:direct_communities, updated_direct_communities)
             |> assign(:institution_communities, updated_institution_communities)
             |> assign(:available_communities, updated_available_communities)
             |> assign(:selected_community_ids, updated_selected_ids)
             |> assign(:error, nil)
             |> assign(:input_value, "")
             |> push_event("focus_input", %{input_id: "community-input-#{socket.assigns.id}"})}
        end

      {:error, _} ->
        {:noreply, assign(socket, :error, "Failed to add community")}
    end
  end

  defp handle_remove_community(community_id, socket) do
    user_id = socket.assigns.user_id

    case Groups.delete_community_account(%{user_id: user_id, community_id: community_id}) do
      {:ok, _} ->
        removed_community =
          Enum.find(socket.assigns.direct_communities, &(&1.id == community_id))

        updated_direct_communities =
          Enum.reject(socket.assigns.direct_communities, &(&1.id == community_id))

        # Recompute institution communities - the removed community might need to show as institution-based
        updated_institution_communities =
          compute_institution_communities(socket.assigns.institution, updated_direct_communities)

        updated_available_communities =
          if removed_community && removed_community not in socket.assigns.available_communities do
            [removed_community | socket.assigns.available_communities]
            |> Enum.sort_by(& &1.name, :asc)
          else
            socket.assigns.available_communities
          end

        updated_selected_ids =
          Enum.map(updated_direct_communities, & &1.id) ++
            Enum.map(updated_institution_communities, & &1.id)

        {:noreply,
         socket
         |> assign(:direct_communities, updated_direct_communities)
         |> assign(:institution_communities, updated_institution_communities)
         |> assign(:available_communities, updated_available_communities)
         |> assign(:selected_community_ids, updated_selected_ids)
         |> assign(:error, nil)
         |> push_event("focus_input", %{input_id: "community-input-#{socket.assigns.id}"})}

      {:error, _} ->
        {:noreply, assign(socket, :error, "Failed to remove community")}
    end
  end

  @impl true
  def render(assigns) do
    # Communities are already ordered by most recently added first
    # Direct communities come first, then institution communities
    all_communities =
      (assigns.direct_communities || []) ++ (assigns.institution_communities || [])

    assigns = assign(assigns, :all_communities, all_communities)
    assigns = assign(assigns, :communities_count, length(all_communities))

    ~H"""
    <div
      class="relative w-full h-full"
      id={"communities-container-#{@id}"}
    >
      <%= cond do %>
        <% @disabled_edit -> %>
          <!-- Disabled/Readonly mode - gray background with comma-separated links -->
          <div class="form-control bg-[var(--color-gray-100)]">
            <%= if Enum.empty?(@all_communities) do %>
              <span class="text-muted">None</span>
            <% else %>
              <%= for {community, index} <- Enum.with_index(@all_communities) do %>
                <.link
                  href={
                    Routes.live_path(OliWeb.Endpoint, OliWeb.CommunityLive.ShowView, community.id)
                  }
                  class="text-primary hover:underline"
                >
                  {community.name}
                </.link>
                <%= if index < @communities_count - 1 do %>
                  <span>, </span>
                <% end %>
              <% end %>
            <% end %>
          </div>
        <% @community_edit_mode -> %>
          <!-- Edit mode open - tags with X buttons (direct only), search input, dropdown -->
          <div class="z-20" phx-click-away="exit_community_edit_mode" phx-target={@myself}>
            <div class="relative w-full h-full">
              <div class="bg-Specially-Tokens-Fill-fill-input border border-Table-table-border rounded-[3px] text-sm w-full h-full min-h-[100px] flex flex-col items-center gap-1 p-2">
                <!-- Direct communities (removable) -->
                <ul class="contents" aria-label="Selected communities">
                  <%= for community <- @direct_communities do %>
                    <li class={"px-3 py-1 mr-auto rounded-full text-sm font-semibold shadow-sm flex items-center gap-2 #{get_community_pill_classes(community.name)}"}>
                      <span>{community.name}</span>
                      <button
                        type="button"
                        phx-click="remove_community"
                        phx-value-community_id={community.id}
                        phx-target={@myself}
                        class="ml-auto text-sm hover:opacity-70 transition-opacity duration-200"
                        aria-label={"Remove #{community.name}"}
                        title={"Remove #{community.name}"}
                      >
                        X
                      </button>
                    </li>
                  <% end %>
                </ul>
                <!-- Institution communities (not removable) -->
                <ul class="contents" aria-label="Communities via institution">
                  <%= for community <- @institution_communities do %>
                    <li
                      class={"px-3 py-1 mr-auto rounded-full text-sm font-semibold shadow-sm flex items-center gap-2 #{get_community_pill_classes(community.name, true)}"}
                      title="Via institution"
                    >
                      <span>{community.name}</span>
                      <span class="text-xs opacity-70">(via institution)</span>
                    </li>
                  <% end %>
                </ul>

                <div class="flex-1 min-w-[180px]">
                  <input
                    type="text"
                    phx-keyup="search_communities"
                    phx-keydown="handle_keydown"
                    phx-debounce={500}
                    phx-target={@myself}
                    value={@input_value}
                    placeholder="Search communities..."
                    aria-label="Search communities"
                    class="w-full px-3 border-0 outline-none text-[#757682] font-semibold focus:bg-transparent focus:ring-0 focus:border-transparent"
                    id={"community-input-#{@id}"}
                  />
                </div>
              </div>

              <div class="absolute top-[calc(100%+1px)] left-0 w-full z-[5] bg-Table-table-row-1 border border-Table-table-border rounded-[3px] max-h-60 overflow-y-auto shadow-xl">
                <%= if Enum.any?(@available_communities, fn community -> community.id not in @selected_community_ids end) do %>
                  <div class="p-3 space-y-2">
                    <div class="text-Text-text-low text-xs font-semibold mb-2">
                      Select an option
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
            class="cursor-pointer w-full min-h-[38px] flex items-start p-2 border border-Table-table-border rounded-[3px] hover:border-Border-border-hover hover:bg-Table-table-hover focus:border focus:border-Border-border-active focus:bg-Table-table-hover focus:outline-none"
            phx-click="toggle_edit"
            phx-keydown="handle_container_keydown"
            phx-target={@myself}
            tabindex="0"
            role="button"
            aria-label="Edit communities"
          >
            <%= if @communities_count > 0 do %>
              <ul class="flex flex-wrap gap-1" aria-label="Communities">
                <%= for community <- @all_communities do %>
                  <li class={"px-3 py-1 rounded-full text-sm font-semibold shadow-sm #{get_community_pill_classes(community.name)}"}>
                    {community.name}
                  </li>
                <% end %>
              </ul>
            <% else %>
              <div class="text-Text-text-low text-sm">
                Click to add communities...
              </div>
            <% end %>
          </div>
      <% end %>

      <%= if @error do %>
        <div class="text-red-500 text-xs mt-1" role="alert" aria-live="assertive">
          {@error}
        </div>
      <% end %>
    </div>
    """
  end

  def get_community_pill_classes(community_name, via_institution \\ false)

  def get_community_pill_classes(_, _via_institution = true) do
    "bg-Fill-Chip-Gray text-Text-Chip-Gray"
  end

  def get_community_pill_classes(community_name, _) do
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
    communities = Groups.list_communities_filtered(search, 50)
    assign(socket, :available_communities, communities)
  end
end
