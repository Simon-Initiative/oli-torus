defmodule OliWeb.Live.Components.Tags.TagsComponent do
  @moduledoc """
  LiveComponent for managing tags in admin tables and forms.

  This component provides tag editing functionality for projects, sections, and products
  in the admin browse tables and overview forms.

  ## Variants

  The component supports two variants with different styling:

  - `:table` (default) - For use in table cells. No background, no border radius, larger padding.
  - `:form` - For use in forms/overview pages. Has background, 4px border radius, smaller padding.

  ## Figma Specs

  ### Table variant
  - Min Height: 35px
  - Border: 1px `Table/table-border`
  - Border radius: 0
  - Padding: 12px top/bottom, 13px left/right
  - Background: none

  ### Form variant (Node 208:11361)
  - Min Height: 40px (hug content)
  - Border: 1px `Border/border-default`
  - Border radius: 4px
  - Padding: 8px top/bottom, 12px left/right
  - Background: `Background/bg-secondary`

  ### Tag Pill (Node 208:11351)
  - Padding: 8px horizontal, 4px vertical
  - Border radius: 999px (fully rounded)
  - Font: Open Sans SemiBold 14px, line-height 16px
  - Shadow: 0px 2px 4px rgba(0, 52, 99, 0.10)
  - Gap between text and X icon: 8px
  - Inner wrapper left padding: 8px
  - X icon: 16x16px (OliWeb.Icons.close_sm)
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
     |> assign(:error, nil)
     |> assign(:input_value, "")
     |> assign(:font_style, "font-family: 'Open Sans', sans-serif;")
     |> assign_new(:variant, fn -> :table end)}
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

    # Sort tags alphabetically by name
    sorted_tags = Enum.sort_by(current_tags, & &1.name, :asc)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:current_tags, sorted_tags)
     |> assign(:selected_tag_ids, Enum.map(sorted_tags, & &1.id))}
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
  def handle_event("toggle_edit_keydown", %{"key" => key}, socket)
      when key in ["Enter", " "] do
    # Delegate to toggle_edit for keyboard activation (WCAG 2.1.1)
    handle_event("toggle_edit", %{}, socket)
  end

  def handle_event("toggle_edit_keydown", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("add_tag", %{"tag_id" => tag_id}, socket) do
    tag_id = String.to_integer(tag_id)
    entity_type = socket.assigns.entity_type
    entity_id = socket.assigns.entity_id

    case associate_tag(entity_type, entity_id, tag_id) do
      {:ok, _} ->
        # Find the tag in available_tags
        case Enum.find(socket.assigns.available_tags, &(&1.id == tag_id)) do
          nil ->
            {:noreply, assign(socket, :error, "Tag not found")}

          tag_to_add ->
            # Add tag to current_tags and sort
            updated_current_tags = [tag_to_add | socket.assigns.current_tags]
            sorted_current_tags = Enum.sort_by(updated_current_tags, & &1.name, :asc)

            # Remove tag from available_tags since it's now selected
            updated_available_tags =
              Enum.reject(socket.assigns.available_tags, &(&1.id == tag_id))

            {:noreply,
             socket
             |> assign(:current_tags, sorted_current_tags)
             |> assign(:available_tags, updated_available_tags)
             |> assign(:selected_tag_ids, Enum.map(sorted_current_tags, & &1.id))
             |> assign(:error, nil)
             |> assign(:input_value, "")
             |> push_event("focus_input", %{input_id: "tag-input-#{socket.assigns.id}"})}
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

        # Check if tag still exists in the database and update available_tags accordingly
        updated_available_tags =
          case result do
            :completely_removed ->
              # Tag was deleted from database, don't add back to available_tags
              socket.assigns.available_tags
              |> Enum.reject(&(&1.id == tag_id))

            _ ->
              # Tag still exists, add it back to available_tags if not already there
              case removed_tag not in socket.assigns.available_tags do
                true ->
                  [removed_tag | socket.assigns.available_tags]
                  |> Enum.sort_by(& &1.name, :asc)

                false ->
                  socket.assigns.available_tags
              end
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
    {:noreply,
     socket
     |> assign(:edit_mode, false)
     |> push_event("focus_container", %{container_id: "tags-display-#{socket.assigns.id}"})}
  end

  @impl true
  def handle_event("handle_keydown", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("exit_edit_mode", params, socket) do
    # Only return focus to container if not exiting via Tab (focusout)
    return_focus = Map.get(params, "return_focus", true)

    socket =
      socket
      |> assign(:edit_mode, false)
      |> assign(:input_value, "")

    socket =
      if return_focus do
        push_event(socket, "focus_container", %{container_id: "tags-display-#{socket.assigns.id}"})
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class="relative w-full h-full"
      id={"tags-container-#{@id}"}
      phx-hook="TagsComponent"
      data-myself={@myself}
    >
      <%= if @edit_mode do %>
        <div class="z-20" phx-click-away="exit_edit_mode" phx-target={@myself}>
          <!-- Edit mode container - full cell -->
          <div class="relative w-full h-full">
            <!-- Edit mode input with selected tags - full cell -->
            <div class={get_edit_container_classes(@variant)}>
              <!-- Show currently selected tags with X buttons -->
              <div
                role="list"
                aria-label="Selected tags"
                class={if @variant == :table, do: "flex flex-col gap-1", else: "flex flex-wrap gap-1"}
              >
                <%= for tag <- @current_tags do %>
                  <.tag_pill
                    tag={tag}
                    variant={@variant}
                    with_button={true}
                    myself={@myself}
                    font_style={@font_style}
                  />
                <% end %>
              </div>
              <!-- Input field for searching/adding new tags -->
              <div class="flex-1 min-w-[180px]">
                <input
                  type="text"
                  phx-keyup="search_tags"
                  phx-keydown="handle_keydown"
                  phx-target={@myself}
                  value={@input_value}
                  class="w-full px-3 border-0 outline-none text-Text-text-low-alpha font-semibold focus:bg-transparent focus:ring-0 focus:border focus:border-Border-border-active"
                  id={"tag-input-#{@id}"}
                  style={@font_style}
                />
              </div>
            </div>
            <!-- Available tags dropdown - positioned below input with full width -->
            <div class="absolute top-[calc(100%+1px)] left-0 w-full z-[5] bg-Table-table-row-1 border border-Table-table-border rounded-[3px] max-h-60 overflow-y-auto shadow-xl">
              <!-- Available tags list -->
              <%= if Enum.any?(@available_tags, fn tag -> tag.id not in @selected_tag_ids end) do %>
                <div class="p-3 space-y-2">
                  <div
                    class="text-Text-text-low text-xs font-semibold mb-2"
                    style={@font_style}
                  >
                    Create or select an option
                  </div>
                  <div class={
                    if @variant == :table, do: "flex flex-col gap-2", else: "flex flex-wrap gap-2"
                  }>
                    <%= for tag <- @available_tags do %>
                      <%= if tag.id not in @selected_tag_ids do %>
                        <button
                          phx-click="add_tag"
                          phx-value-tag_id={tag.id}
                          phx-target={@myself}
                          class={
                            if @variant == :table,
                              do:
                                "px-3 py-1 mr-auto rounded-full text-sm font-semibold shadow-sm transition-colors hover:opacity-80 #{get_tag_pill_classes(tag.name)}",
                              else:
                                "px-2 py-1 rounded-full text-sm leading-4 font-semibold transition-colors hover:opacity-80 #{get_tag_pill_classes(tag.name)}"
                          }
                          style={@font_style}
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
        <!-- Display mode -->
        <%!--
          Keyboard activation works for both variants (WCAG 2.1.1)
          role="button" only for :table variant to avoid nested interactive controls (WCAG)
          :form variant has remove buttons inside, so no role="button" on container
        --%>
        <div
          id={"tags-display-#{@id}"}
          class={get_display_container_classes(@variant)}
          phx-click="toggle_edit"
          phx-keydown="toggle_edit_keydown"
          phx-target={@myself}
          tabindex="0"
          role={if @variant == :table, do: "button"}
          aria-label={
            if @variant == :table, do: "Edit tags", else: "Tags, click or press Enter to edit"
          }
        >
          <%= if length(@current_tags || []) > 0 do %>
            <div
              role="list"
              aria-label="Selected tags"
              class={if @variant == :table, do: "flex flex-col gap-1", else: "flex flex-wrap gap-1"}
            >
              <%= for tag <- @current_tags do %>
                <.tag_pill
                  tag={tag}
                  variant={@variant}
                  with_button={@variant == :form}
                  myself={@myself}
                  font_style={@font_style}
                />
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

  @doc """
  Returns the CSS classes for tag pills.
  Uses consistent color based on tag name hash.
  """
  def get_tag_pill_classes(tag_name) do
    color_combinations = [
      "bg-Fill-Accent-fill-accent-purple text-Text-text-accent-purple",
      "bg-Fill-Accent-fill-accent-blue text-Text-text-accent-blue",
      "bg-Fill-Accent-fill-accent-orange text-Text-text-accent-orange",
      "bg-Fill-Accent-fill-accent-teal text-Text-text-accent-teal"
    ]

    # Convert tag name to a consistent number between 0 and 3
    hash = :erlang.phash2(tag_name, 4)
    "#{Enum.at(color_combinations, hash)} shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)]"
  end

  @doc """
  Returns the CSS classes for the display mode container based on variant.

  ## Variants
  - `:table` - Original table styling (no changes)
  - `:form` - Form/overview page styling (customize as needed)
  """
  def get_display_container_classes(:table) do
    # TABLE VARIANT - Original from git HEAD
    "cursor-pointer w-full min-h-[100px] flex items-start p-2 border border-transparent hover:border-Border-border-active hover:bg-Table-table-hover focus:border focus:border-Border-border-active focus:bg-Table-table-hover focus:outline-none"
  end

  def get_display_container_classes(:form) do
    # FORM VARIANT - Figma node 208:11361 (no background change on hover, per Figma)
    "cursor-pointer w-full min-h-[40px] flex items-center py-2 px-3 bg-Background-bg-secondary border border-Border-border-default rounded hover:border-Border-border-active focus:border-Border-border-active focus:outline-none"
  end

  @doc """
  Returns the CSS classes for the edit mode container based on variant.
  """
  def get_edit_container_classes(:table) do
    # TABLE VARIANT - Original from git HEAD
    "bg-Specially-Tokens-Fill-fill-input border border-Table-table-border rounded-[3px] text-sm w-full h-full min-h-[100px] flex flex-col items-center gap-1 p-2"
  end

  def get_edit_container_classes(:form) do
    # FORM VARIANT - Figma node 208:11361
    "bg-Background-bg-secondary border border-Border-border-default rounded text-sm w-full h-full min-h-[40px] flex flex-wrap items-center gap-1 py-2 px-3"
  end

  # Renders a tag pill with optional remove button.
  attr :tag, :map, required: true
  attr :variant, :atom, required: true
  attr :with_button, :boolean, default: true
  attr :myself, :any, required: true
  attr :font_style, :string, required: true

  defp tag_pill(assigns) do
    ~H"""
    <span
      role="listitem"
      class={get_tag_pill_span_classes(@variant, @with_button, @tag.name)}
      style={@font_style}
    >
      <%= if @with_button do %>
        <span class={if @variant == :form, do: "pl-2"}>{@tag.name}</span>
        <button
          phx-click="remove_tag"
          phx-value-tag_id={@tag.id}
          phx-target={@myself}
          class="hover:opacity-70 transition-opacity duration-200 flex items-center justify-center"
          type="button"
          aria-label={"Remove tag #{@tag.name}"}
        >
          <OliWeb.Icons.close_sm class="w-4 h-4 stroke-current" />
        </button>
      <% else %>
        {@tag.name}
      <% end %>
    </span>
    """
  end

  defp get_tag_pill_span_classes(:table, true, tag_name) do
    "px-3 py-1 mr-auto rounded-full text-sm font-semibold shadow-sm flex items-center gap-2 #{get_tag_pill_classes(tag_name)}"
  end

  defp get_tag_pill_span_classes(:table, false, tag_name) do
    "px-3 py-1 mr-auto rounded-full text-sm font-semibold shadow-sm #{get_tag_pill_classes(tag_name)}"
  end

  defp get_tag_pill_span_classes(:form, _with_button, tag_name) do
    "px-2 py-1 rounded-full text-sm leading-4 font-semibold flex items-center gap-2 #{get_tag_pill_classes(tag_name)}"
  end

  # Private functions

  defp load_available_tags(socket, search \\ "") do
    tags = Tags.list_tags(%{search: search, limit: 50})
    assign(socket, :available_tags, tags)
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
