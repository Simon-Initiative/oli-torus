defmodule OliWeb.Components.FilterPanel do
  @moduledoc """
  A stateful LiveComponent for managing filter panels with tag search and suggestions.

  ## State Management

  This component manages its own draft state while the filter panel is open.
  When the panel is closed, the parent LiveView is the source of truth for filter values.

  ## Message Passing

  The component sends messages to the parent LiveView when filters are applied or cleared:
    - `{:filter_panel, :apply, filters}` - User applied filters
    - `{:filter_panel, :clear}` - User cleared all filters

  The parent should handle these with `handle_info/2` callbacks.

  ## Required Assigns

    - `:id` - Unique identifier for the component
    - `:parent_pid` - PID of the parent LiveView (use `self()`)
    - `:filters` - %BrowseFilters.State{} struct with current filter values

  ## Optional Assigns

    - `:fields` - List of filter fields to display (default: all)
    - `:date_field_options` - Options for date field dropdown
    - `:visibility_options` - Options for visibility dropdown
    - `:status_options` - Options for status dropdown
    - `:published_options` - Options for published dropdown
    - `:institution_options` - Options for institution dropdown
  """

  use OliWeb, :live_component

  alias Phoenix.LiveView.JS
  alias OliWeb.Icons
  alias OliWeb.Admin.BrowseFilters
  alias OliWeb.Live.Components.Tags.TagsComponent
  alias Oli.Tags

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       filter_panel_open: false,
       tag_search: "",
       tag_suggestions: []
     )}
  end

  @impl true
  def update(assigns, socket) do
    # Preserve draft filters and search state when panel is open (user is editing)
    # Otherwise, accept new filters from parent (e.g., from URL params on navigation)
    assigns =
      if socket.assigns[:filter_panel_open] do
        assigns
        |> Map.delete(:filters)
        |> Map.delete(:tag_search)
        |> Map.delete(:tag_suggestions)
      else
        assigns
      end

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:form_id, fn -> "#{assigns.id}-form" end)
      |> assign(:active_count, BrowseFilters.active_count(assigns.filters))
      |> assign_new(:date_field_options, fn -> [] end)
      |> assign_new(:visibility_options, fn -> [] end)
      |> assign_new(:status_options, fn -> [] end)
      |> assign_new(:published_options, fn -> [] end)
      |> assign_new(:institution_options, fn -> [] end)
      |> assign_new(:fields, fn ->
        [:date, :tags, :visibility, :published, :status, :institution]
      end)

    ~H"""
    <div id={@id} class="relative flex items-center gap-4">
      <button
        class={[
          "ml-2 text-center text-Text-text-high text-sm font-normal leading-none flex items-center gap-x-1 rounded px-2 py-1.5 transition-colors hover:text-Text-text-button",
          if(@active_count > 0, do: "bg-Fill-Buttons-fill-primary-muted", else: "")
        ]}
        phx-click={JS.toggle(to: "##{@id}-panel") |> JS.push("toggle_filters", target: @myself)}
        type="button"
      >
        <Icons.filter class="stroke-Text-text-high" />
        <span>Filter</span>
        <span
          :if={@active_count > 0}
          class="ml-1 inline-flex h-5 min-w-[1.25rem] items-center justify-center rounded-full bg-Text-text-button px-1 text-xs font-semibold text-Text-text-white"
        >
          {@active_count}
        </span>
      </button>

      <button
        class="ml-2 mr-4 text-center text-Text-text-high text-sm font-normal leading-none flex items-center gap-x-1 hover:text-Text-text-button"
        phx-click="clear_all_filters"
        phx-target={@myself}
        type="button"
      >
        <Icons.trash /> Clear All Filters
      </button>

      <div
        id={"#{@id}-panel"}
        class={[
          "absolute left-0 top-10 z-50 w-[430px] rounded-lg border border-Border-border-default bg-Surface-surface-primary shadow-[0px_12px_24px_0px_rgba(53,55,64,0.12)]",
          if(@filter_panel_open, do: "", else: "hidden")
        ]}
        phx-click-away={JS.hide(to: "##{@id}-panel") |> JS.push("close_filters", target: @myself)}
      >
        <.form
          id={@form_id}
          for={%{}}
          as={:filters}
          phx-submit="apply_filters"
          phx-target={@myself}
          class="flex flex-col gap-4 p-5"
        >
          <%= if :date in @fields do %>
            <div class="flex flex-col gap-2">
              <div class="flex flex-col gap-1">
                <span class="text-sm font-semibold text-Text-text-high">Date</span>
                <span class="text-xs text-Text-text-low-alpha">
                  If both dates are specified, they will be interpreted as a range.
                </span>
              </div>
              <div class="flex flex-col gap-2">
                <select
                  name="filters[date_field]"
                  class="h-9 rounded border border-Border-border-default px-3 text-sm text-Text-text-high dark:bg-transparent"
                  value={encode_atom(@filters.date_field)}
                >
                  <option
                    :for={{value, label} <- date_field_option_values(@date_field_options)}
                    value={value}
                    selected={value == encode_atom(@filters.date_field)}
                  >
                    {label}
                  </option>
                </select>
                <div class="flex items-center gap-2">
                  <div class="flex flex-1 flex-col gap-1">
                    <label class="text-xs font-medium text-Text-text-low-alpha">
                      is after
                    </label>
                    <input
                      type="date"
                      name="filters[date_from]"
                      value={format_date(@filters.date_from)}
                      class="h-9 rounded border border-Border-border-default px-3 text-sm text-Text-text-high dark:bg-transparent"
                    />
                  </div>
                  <div class="mt-6 text-xs text-Text-text-low-alpha">and/or before</div>
                  <div class="flex flex-1 flex-col gap-1">
                    <label class="text-xs font-medium text-Text-text-low-alpha invisible">
                      and/or before
                    </label>
                    <input
                      type="date"
                      name="filters[date_to]"
                      value={format_date(@filters.date_to)}
                      class="h-9 rounded border border-Border-border-default px-3 text-sm text-Text-text-high dark:bg-transparent"
                    />
                  </div>
                </div>
              </div>
            </div>
          <% end %>

          <%= if :tags in @fields do %>
            <div class="flex flex-col gap-2">
              <span class="text-sm font-semibold text-Text-text-high">Tags</span>
              <div class="flex flex-wrap gap-2">
                <%= for tag <- @filters.tags || [] do %>
                  <span class={"inline-flex items-center gap-2 rounded-full px-3 py-1 text-xs font-medium #{TagsComponent.get_tag_pill_classes(tag.name)}"}>
                    {tag.name}
                    <button
                      type="button"
                      class="hover:opacity-80"
                      phx-click="filter_remove_tag"
                      phx-target={@myself}
                      phx-value-id={tag.id}
                    >
                      ×
                    </button>
                  </span>
                <% end %>
              </div>

              <%= for tag <- @filters.tags || [] do %>
                <input type="hidden" name="filters[tag_ids][]" value={tag.id} />
              <% end %>

              <input
                type="text"
                id={"#{@id}-tag-search"}
                name="filters[tag_search_input]"
                value={@tag_search}
                placeholder="Enter tags"
                phx-keyup="filter_tag_search"
                phx-target={@myself}
                phx-debounce="300"
                class="h-9 rounded border border-Border-border-default px-3 text-sm text-Text-text-high focus:border-Text-text-button focus:outline-none dark:bg-transparent"
              />

              <div
                :if={Enum.any?(@tag_suggestions)}
                class="flex flex-col gap-1 rounded border border-Border-border-default bg-Specially-Tokens-Fill-fill-nav-hover p-2"
              >
                <button
                  :for={suggestion <- @tag_suggestions}
                  type="button"
                  class="rounded px-2 py-1 text-left text-sm text-Text-text-high hover:bg-Specially-Tokens-Fill-fill-dot-message-default"
                  phx-click="filter_add_tag"
                  phx-target={@myself}
                  phx-value-id={suggestion.id}
                  phx-value-name={suggestion.name}
                >
                  {suggestion.name}
                </button>
              </div>
            </div>
          <% end %>

          <%= if :visibility in @fields do %>
            <div class="flex flex-col gap-2">
              <label class="text-sm font-semibold text-Text-text-high">
                Visibility
              </label>
              <select
                name="filters[visibility]"
                class="h-9 rounded border border-Border-border-default px-3 text-sm text-Text-text-high dark:bg-transparent"
                value={encode_atom(@filters.visibility)}
              >
                <option value="">Select option</option>
                <option
                  :for={{value, label} <- @visibility_options}
                  value={Atom.to_string(value)}
                  selected={value == @filters.visibility}
                >
                  {label}
                </option>
              </select>
            </div>
          <% end %>

          <%= if :published in @fields do %>
            <div class="flex flex-col gap-2">
              <label class="text-sm font-semibold text-Text-text-high">
                Published
              </label>
              <select
                name="filters[published]"
                class="h-9 rounded border border-Border-border-default px-3 text-sm text-Text-text-high dark:bg-transparent"
                value={encode_boolean(@filters.published)}
              >
                <option value="">Select option</option>
                <option
                  :for={{value, label} <- @published_options}
                  value={encode_boolean(value)}
                  selected={value == @filters.published}
                >
                  {label}
                </option>
              </select>
            </div>
          <% end %>

          <%= if :status in @fields do %>
            <div class="flex flex-col gap-2">
              <label class="text-sm font-semibold text-Text-text-high">Status</label>
              <select
                name="filters[status]"
                class="h-9 rounded border border-Border-border-default px-3 text-sm text-Text-text-high dark:bg-transparent"
                value={encode_atom(@filters.status)}
              >
                <option value="">Select option</option>
                <option
                  :for={{value, label} <- @status_options}
                  value={Atom.to_string(value)}
                  selected={value == @filters.status}
                >
                  {label}
                </option>
              </select>
            </div>
          <% end %>

          <%= if :institution in @fields do %>
            <div class="flex flex-col gap-2">
              <label class="text-sm font-semibold text-Text-text-high">
                Institution
              </label>
              <select
                name="filters[institution]"
                class="h-9 rounded border border-Border-border-default px-3 text-sm text-Text-text-high dark:bg-transparent"
                value={encode_integer(@filters.institution_id)}
              >
                <option value="">Select option</option>
                <option
                  :for={institution <- @institution_options}
                  value={Integer.to_string(institution.id)}
                  selected={institution.id == @filters.institution_id}
                >
                  {institution.name}
                </option>
              </select>
            </div>
          <% end %>

          <div class="flex justify-end gap-3 pt-2">
            <button
              type="button"
              class="text-sm font-semibold text-Text-text-button hover:text-Text-text-button-hover"
              phx-click={JS.hide(to: "##{@id}-panel") |> JS.push("cancel_filters", target: @myself)}
            >
              Cancel
            </button>
            <button
              type="submit"
              class="rounded bg-Fill-Buttons-fill-primary px-4 py-2 text-sm font-semibold text-Text-text-white hover:bg-Fill-Buttons-fill-primary-hover"
            >
              Apply
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("toggle_filters", _, socket) do
    {:noreply, assign(socket, filter_panel_open: !socket.assigns.filter_panel_open)}
  end

  @impl true
  def handle_event("close_filters", _, socket) do
    {:noreply, assign(socket, filter_panel_open: false)}
  end

  @impl true
  def handle_event("cancel_filters", _, socket) do
    {:noreply, assign(socket, filter_panel_open: false, tag_suggestions: [])}
  end

  @impl true
  def handle_event("filter_tag_search", %{"value" => value}, socket) do
    term = value || ""
    trimmed = String.trim(term)

    suggestions =
      if trimmed == "" do
        []
      else
        Tags.list_tags(%{search: trimmed, limit: 8})
        |> Enum.map(&%{id: &1.id, name: &1.name})
      end

    {:noreply, assign(socket, tag_search: term, tag_suggestions: suggestions)}
  end

  @impl true
  def handle_event("filter_add_tag", %{"id" => id_str} = params, socket) do
    with {:ok, id} <- parse_positive_int(id_str),
         {:ok, tag} <- fetch_tag_from_params(params, id) do
      filters = BrowseFilters.add_tag(socket.assigns.filters, tag)
      suggestions = Enum.reject(socket.assigns.tag_suggestions, &(&1.id == id))

      {:noreply,
       assign(socket,
         filters: filters,
         tag_search: "",
         tag_suggestions: suggestions
       )}
    else
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("filter_remove_tag", %{"id" => id_str}, socket) do
    with {:ok, id} <- parse_positive_int(id_str) do
      filters = BrowseFilters.remove_tag(socket.assigns.filters, id)

      {:noreply, assign(socket, filters: filters)}
    else
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("apply_filters", %{"filters" => filters_params}, socket) do
    normalized = BrowseFilters.normalize_form_params(filters_params)
    filters = BrowseFilters.parse(normalized)

    send(socket.assigns.parent_pid, {:filter_panel, :apply, filters})

    {:noreply,
     assign(socket,
       filters: filters,
       filter_panel_open: false,
       tag_search: "",
       tag_suggestions: []
     )}
  end

  @impl true
  def handle_event("apply_filters", _params, socket) do
    handle_event("apply_filters", %{"filters" => %{}}, socket)
  end

  @impl true
  def handle_event("clear_all_filters", _params, socket) do
    filters = BrowseFilters.default()

    send(socket.assigns.parent_pid, {:filter_panel, :clear})

    {:noreply,
     assign(socket,
       filters: filters,
       filter_panel_open: false,
       tag_search: "",
       tag_suggestions: []
     )}
  end

  defp date_field_option_values([]), do: [{"inserted_at", "Created Date"}]
  defp date_field_option_values(options), do: options

  defp format_date(nil), do: nil
  defp format_date(%Date{} = date), do: Date.to_iso8601(date)

  defp encode_atom(nil), do: ""
  defp encode_atom(atom) when is_atom(atom), do: Atom.to_string(atom)

  defp encode_boolean(nil), do: ""
  defp encode_boolean(value) when is_boolean(value), do: if(value, do: "true", else: "false")

  defp encode_integer(nil), do: ""
  defp encode_integer(int) when is_integer(int), do: Integer.to_string(int)

  defp parse_positive_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int >= 0 -> {:ok, int}
      _ -> :error
    end
  end

  defp parse_positive_int(value) when is_integer(value) and value >= 0, do: {:ok, value}
  defp parse_positive_int(_), do: :error

  defp fetch_tag_from_params(%{"name" => name}, id) when is_binary(name) and name != "" do
    {:ok, %{id: id, name: name}}
  end

  defp fetch_tag_from_params(_params, id) do
    case Tags.list_tags_by_ids([id]) do
      [tag] -> {:ok, %{id: tag.id, name: tag.name}}
      _ -> :error
    end
  end
end
