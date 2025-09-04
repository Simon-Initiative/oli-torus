defmodule OliWeb.Live.Components.Tags.TagsComponent do
  @moduledoc """
  LiveComponent for managing tags in admin tables.

  This component provides tag editing functionality for projects, sections, and products
  in the admin browse tables.
  """

  use OliWeb, :live_component

  alias Oli.Tags

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:edit_mode, false)
     |> assign(:available_tags, [])
     |> assign(:selected_tag_ids, [])
     |> assign(:loading, false)
     |> assign(:error, nil)
     |> assign(:input_value, "")}
  end

  @impl true
  def update(assigns, socket) do
    entity_type = assigns.entity_type
    entity_id = assigns.entity_id
    current_tags = assigns.current_tags || []

    # If current_tags is empty or not loaded, load them from the database
    current_tags =
      cond do
        # Check if it's an unloaded association
        match?(%Ecto.Association.NotLoaded{}, current_tags) ->
          get_entity_tags(entity_type, entity_id)

        # Check if it's an empty list
        is_list(current_tags) and Enum.empty?(current_tags) ->
          get_entity_tags(entity_type, entity_id)

        # Otherwise use the provided tags
        true ->
          current_tags
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:current_tags, current_tags)
     |> assign(:selected_tag_ids, Enum.map(current_tags, & &1.id))}
  end

  @impl true
  def handle_event("toggle_edit", _params, socket) do
    new_edit_mode = !socket.assigns.edit_mode
    socket = assign(socket, :edit_mode, new_edit_mode)

    # If entering edit mode, load available tags and focus the input field
    socket =
      if new_edit_mode do
        socket
        |> load_available_tags()
        |> push_event("focus_input", %{input_id: "tag-input-#{socket.assigns.id}"})
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("add_tag", %{"tag_id" => tag_id}, socket) do
    tag_id = String.to_integer(tag_id)
    entity_type = socket.assigns.entity_type
    entity_id = socket.assigns.entity_id

    case associate_tag(entity_type, entity_id, tag_id) do
      {:ok, _} ->
        # Find the tag in available_tags
        tag_to_add = Enum.find(socket.assigns.available_tags, &(&1.id == tag_id))

        if tag_to_add do
          # Add tag to current_tags and sort
          updated_current_tags = [tag_to_add | socket.assigns.current_tags]
          sorted_current_tags = Enum.sort_by(updated_current_tags, & &1.name, :asc)

          # Remove tag from available_tags since it's now selected
          updated_available_tags = Enum.reject(socket.assigns.available_tags, &(&1.id == tag_id))

          {:noreply,
           socket
           |> assign(:current_tags, sorted_current_tags)
           |> assign(:available_tags, updated_available_tags)
           |> assign(:selected_tag_ids, Enum.map(sorted_current_tags, & &1.id))
           |> assign(:error, nil)
           |> assign(:input_value, "")
           |> push_event("focus_input", %{input_id: "tag-input-#{socket.assigns.id}"})}
        else
          {:noreply, assign(socket, :error, "Tag not found")}
        end

      {:error, _} ->
        {:noreply, assign(socket, :error, "Failed to add tag")}
    end
  end

  @impl true
  def handle_event("remove_tag", %{"tag_id" => tag_id}, socket) do
    tag_id = String.to_integer(tag_id)
    entity_type = socket.assigns.entity_type
    entity_id = socket.assigns.entity_id

    case remove_tag(entity_type, entity_id, tag_id, remove_if_unused: true) do
      {:ok, _, result} ->
        # Find and remove the tag from current_tags
        removed_tag = Enum.find(socket.assigns.current_tags, &(&1.id == tag_id))

        updated_current_tags = Enum.reject(socket.assigns.current_tags, &(&1.id == tag_id))

        # Check if tag still exists in the database
        tag_still_exists = result != :completely_removed

        updated_available_tags =
          if tag_still_exists do
            # Tag still exists, add it back to available_tags
            if removed_tag not in socket.assigns.available_tags do
              [removed_tag | socket.assigns.available_tags]
              |> Enum.sort_by(& &1.name, :asc)
            else
              socket.assigns.available_tags
            end
          else
            # Tag was deleted from database, don't add back to available_tags
            socket.assigns.available_tags
            |> Enum.reject(&(&1.id == tag_id))
          end

        {:noreply,
         socket
         |> assign(:current_tags, updated_current_tags)
         |> assign(:available_tags, updated_available_tags)
         |> assign(:selected_tag_ids, Enum.map(updated_current_tags, & &1.id))
         |> assign(:error, nil)
         |> push_event("focus_input", %{input_id: "tag-input-#{socket.assigns.id}"})}

      {:error, _} ->
        {:noreply, assign(socket, :error, "Failed to remove tag")}
    end
  end

  @impl true
  def handle_event("create_tag", %{"name" => name}, socket) do
    case Tags.create_tag(%{name: name}) do
      {:ok, tag} ->
        # Add new tag to available tags
        available_tags = [tag | socket.assigns.available_tags]

        {:noreply,
         assign(socket, :available_tags, available_tags)
         |> push_event("focus_input", %{input_id: "tag-input-#{socket.assigns.id}"})}

      {:error, _} ->
        {:noreply, assign(socket, :error, "Failed to create tag")}
    end
  end

  @impl true
  def handle_event("search_tags", params, socket) do
    search = Map.get(params, "value") || Map.get(params, "search") || ""

    {:noreply,
     socket
     |> assign(:input_value, search)
     |> then(&load_available_tags(&1, search))}
  end

  @impl true
  def handle_event("handle_keydown", %{"key" => "Enter"}, socket) do
    # Get the current input value and create a tag
    {:noreply, create_tag_from_input_value(socket)}
  end

  @impl true
  def handle_event("handle_keydown", %{"key" => "Escape"}, socket) do
    {:noreply, assign(socket, :edit_mode, false)}
  end

  @impl true
  def handle_event("handle_keydown", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("exit_edit_mode", _params, socket) do
    {:noreply,
     socket
     |> assign(:edit_mode, false)
     |> assign(:input_value, "")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative w-full h-full" id={"tags-container-#{@id}"} phx-hook="TagsComponent">
      <%= if @edit_mode do %>
        <div class="z-20" phx-click-away="exit_edit_mode" phx-target={@myself}>
          <!-- Edit mode container - full cell -->
          <div class="relative w-full h-full">
            <!-- Edit mode input with selected tags - full cell -->
            <div class="bg-white border border-[#ced1d9] rounded-[3px] text-sm w-full h-full min-h-[36px] flex flex-col items-center gap-1 p-2">
              <!-- Show currently selected tags with X buttons -->
              <%= for tag <- @current_tags do %>
                <span
                  class={"px-3 py-1 mr-auto rounded-full text-sm font-semibold shadow-sm flex items-center gap-2 #{get_tag_pill_classes(tag.name)}"}
                  style="font-family: 'Open Sans', sans-serif;"
                >
                  <span>{tag.name}</span>
                  <button
                    phx-click="remove_tag"
                    phx-value-tag_id={tag.id}
                    phx-target={@myself}
                    class="ml-auto text-sm hover:opacity-70 transition-opacity duration-200"
                    type="button"
                  >
                    X
                  </button>
                </span>
              <% end %>
              
    <!-- Input field for searching/adding new tags -->
              <div class="flex-1 min-w-[180px]">
                <input
                  type="text"
                  phx-keyup="search_tags"
                  phx-keydown="handle_keydown"
                  phx-target={@myself}
                  value={@input_value}
                  class="w-full px-3 border-0 outline-none text-[#757682] font-semibold focus:outline-none focus:ring-0 focus:border-transparent"
                  id={"tag-input-#{@id}"}
                  style="font-family: 'Open Sans', sans-serif;"
                />
              </div>
            </div>
            
    <!-- Available tags dropdown - positioned below input with full width -->
            <div class="absolute top-[calc(100%+1px)] left-0 w-full z-[5] bg-[#f3f4f8] border border-[#ced1d9] rounded-[3px] max-h-60 overflow-y-auto shadow-xl">
              <!-- Available tags list -->
              <%= if Enum.any?(@available_tags, fn tag -> tag.id not in @selected_tag_ids end) do %>
                <div class="p-3 space-y-2">
                  <div
                    class="text-[#757682] text-xs font-semibold mb-2"
                    style="font-family: 'Open Sans', sans-serif;"
                  >
                    Create or select an option
                  </div>
                  <div class="flex flex-col gap-2">
                    <%= for tag <- @available_tags do %>
                      <%= if tag.id not in @selected_tag_ids do %>
                        <button
                          phx-click="add_tag"
                          phx-value-tag_id={tag.id}
                          phx-target={@myself}
                          class={"px-3 py-1 mr-auto rounded-full text-sm font-semibold shadow-sm transition-colors hover:opacity-80 #{get_tag_pill_classes(tag.name)}"}
                          style="font-family: 'Open Sans', sans-serif;"
                        >
                          {tag.name}
                        </button>
                      <% end %>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% else %>
        <!-- Display mode - clean pills without X buttons -->
        <div
          class="cursor-pointer w-full min-h-[32px] flex items-start p-2"
          phx-click="toggle_edit"
          phx-target={@myself}
        >
          <%= if length(@current_tags || []) > 0 do %>
            <div class="flex flex-col gap-1">
              <%= for tag <- @current_tags do %>
                <span
                  class={"px-3 py-1 mr-auto rounded-full text-sm font-semibold shadow-sm #{get_tag_pill_classes(tag.name)}"}
                  style="font-family: 'Open Sans', sans-serif;"
                >
                  {tag.name}
                </span>
              <% end %>
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

  # Private functions

  defp get_tag_pill_classes(tag_name) do
    # Define color combinations matching Figma design
    color_combinations = [
      # Purple
      "bg-[#f7def8] text-[#9a40a8]",
      # Blue
      "bg-[#deecff] text-[#1b67b2]",
      # Orange
      "bg-[#ffecde] text-[#a94f0e]",
      # Teal
      "bg-[#dcf3f5] text-[#00525c]"
    ]

    # Convert tag name to a consistent number between 0 and 3
    hash = :erlang.phash2(tag_name, 4)
    Enum.at(color_combinations, hash)
  end

  defp load_available_tags(socket, search \\ "") do
    try do
      tags = Tags.list_tags(%{search: search, limit: 50})
      assign(socket, :available_tags, tags)
    rescue
      _ ->
        assign(socket, :error, "Failed to load tags")
    end
  end

  defp get_entity_tags(:project, project_id) do
    Tags.get_project_tags(project_id)
  end

  defp get_entity_tags(:section, section_id) do
    Tags.get_section_tags(section_id)
  end

  defp associate_tag(:project, project_id, tag_id) do
    Tags.associate_tag_with_project(project_id, tag_id)
  end

  defp associate_tag(:section, section_id, tag_id) do
    Tags.associate_tag_with_section(section_id, tag_id)
  end

  defp remove_tag(:project, project_id, tag_id, opts) do
    Tags.remove_tag_from_project(project_id, tag_id, opts)
  end

  defp remove_tag(:section, section_id, tag_id, opts) do
    Tags.remove_tag_from_section(section_id, tag_id, opts)
  end

  defp create_tag_from_input_value(socket) do
    input_value = String.trim(socket.assigns.input_value)

    if input_value == "" do
      assign(socket, :error, "Please enter a tag name")
    else
      # First try to find existing tag with this name
      existing_tag =
        Enum.find(socket.assigns.available_tags, fn tag ->
          String.downcase(tag.name) == String.downcase(input_value)
        end)

      case existing_tag do
        # If tag exists, add it directly
        %{id: tag_id} ->
          entity_type = socket.assigns.entity_type
          entity_id = socket.assigns.entity_id

          case associate_tag(entity_type, entity_id, tag_id) do
            {:ok, _} ->
              # Add existing tag to current_tags and sort
              updated_current_tags = [existing_tag | socket.assigns.current_tags]
              sorted_current_tags = Enum.sort_by(updated_current_tags, & &1.name, :asc)

              # Remove tag from available_tags since it's now selected
              updated_available_tags =
                Enum.reject(socket.assigns.available_tags, &(&1.id == tag_id))

              socket
              |> assign(:current_tags, sorted_current_tags)
              |> assign(:available_tags, updated_available_tags)
              |> assign(:selected_tag_ids, Enum.map(sorted_current_tags, & &1.id))
              |> assign(:input_value, "")
              |> assign(:error, nil)
              |> push_event("focus_input", %{
                input_id: "tag-input-#{socket.assigns.id}",
                clear: true
              })

            {:error, _} ->
              assign(socket, :error, "Failed to associate existing tag")
          end

        # If tag doesn't exist, create it
        nil ->
          case Tags.create_tag(%{name: input_value}) do
            {:ok, tag} ->
              # Associate the new tag with the entity
              entity_type = socket.assigns.entity_type
              entity_id = socket.assigns.entity_id

              case associate_tag(entity_type, entity_id, tag.id) do
                {:ok, _} ->
                  # Add new tag to current_tags and sort
                  updated_current_tags = [tag | socket.assigns.current_tags]
                  sorted_current_tags = Enum.sort_by(updated_current_tags, & &1.name, :asc)

                  # Add new tag to available_tags and sort (in case user wants to use it elsewhere)
                  updated_available_tags = [tag | socket.assigns.available_tags]
                  sorted_available_tags = Enum.sort_by(updated_available_tags, & &1.name, :asc)

                  socket
                  |> assign(:available_tags, sorted_available_tags)
                  |> assign(:current_tags, sorted_current_tags)
                  |> assign(:selected_tag_ids, Enum.map(sorted_current_tags, & &1.id))
                  |> assign(:input_value, "")
                  |> assign(:error, nil)
                  |> push_event("focus_input", %{
                    input_id: "tag-input-#{socket.assigns.id}",
                    clear: true
                  })

                {:error, _} ->
                  assign(socket, :error, "Tag created but failed to associate with entity")
              end

            {:error, _changeset} ->
              # Even if creation fails, try to find the tag that might have been created by another process
              # Load fresh available tags and try to find the tag
              socket_with_fresh_tags = load_available_tags(socket)

              fresh_existing_tag =
                Enum.find(socket_with_fresh_tags.assigns.available_tags, fn tag ->
                  String.downcase(tag.name) == String.downcase(input_value)
                end)

              case fresh_existing_tag do
                %{id: tag_id} ->
                  # Found the tag, associate it
                  entity_type = socket.assigns.entity_type
                  entity_id = socket.assigns.entity_id

                  case associate_tag(entity_type, entity_id, tag_id) do
                    {:ok, _} ->
                      # Find the tag that was created and add it to current_tags
                      found_tag =
                        Enum.find(
                          socket_with_fresh_tags.assigns.available_tags,
                          &(&1.id == tag_id)
                        )

                      if found_tag do
                        # Add tag to current_tags and sort
                        updated_current_tags = [found_tag | socket.assigns.current_tags]
                        sorted_current_tags = Enum.sort_by(updated_current_tags, & &1.name, :asc)

                        socket_with_fresh_tags
                        |> assign(:current_tags, sorted_current_tags)
                        |> assign(:selected_tag_ids, Enum.map(sorted_current_tags, & &1.id))
                        |> assign(:input_value, "")
                        |> assign(:error, nil)
                        |> push_event("focus_input", %{
                          input_id: "tag-input-#{socket.assigns.id}",
                          clear: true
                        })
                      else
                        assign(socket_with_fresh_tags, :error, "Failed to find created tag")
                      end

                    {:error, _} ->
                      assign(socket_with_fresh_tags, :error, "Failed to associate tag")
                  end

                nil ->
                  assign(socket, :error, "Failed to create tag")
              end
          end
      end
    end
  end
end
