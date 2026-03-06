defmodule OliWeb.Components.Delivery.ListNavigator do
  @moduledoc """
  A component that allows the user to navigate through a list of items.
  Renders the current item with previous/next controls, and a searchable dropdown for direct selection.

  Items can be of type page, unit, module, or section.
  """

  use OliWeb, :live_component
  alias OliWeb.Icons
  alias OliWeb.Common.Utils

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def update(assigns, socket) do
    # Find the current item's index in the list
    current_index =
      assigns.items
      |> Enum.with_index()
      |> Enum.find_value(fn {item, index} ->
        if item.resource_id == assigns.current_item_resource_id, do: index
      end)

    # Get the previous, current, and next items based on the index
    {previous_item, current_item, next_item} =
      case current_index do
        nil ->
          {nil, nil, nil}

        index ->
          current_item = Enum.at(assigns.items, index)
          previous_item = if index > 0, do: Enum.at(assigns.items, index - 1), else: nil

          next_item =
            if index < length(assigns.items) - 1, do: Enum.at(assigns.items, index + 1), else: nil

          {previous_item, current_item, next_item}
      end

    socket =
      assign(socket, %{
        current_item: current_item,
        current_item_label: if(current_item, do: resource_label(current_item), else: ""),
        previous_item: previous_item,
        next_item: next_item,
        all_items: assigns.items,
        filtered_items: assigns.items,
        path_builder_fn: assigns.path_builder_fn,
        navigation_type: Map.get(assigns, :navigation_type, :navigate),
        search_query: ""
      })

    {:ok, socket}
  end

  def handle_event("search", %{"value" => query}, socket) do
    filtered_items =
      if String.trim(query) == "" do
        socket.assigns.all_items
      else
        searchable_items(socket.assigns.all_items, socket.assigns.current_item)
        |> Enum.filter(fn item ->
          String.contains?(String.downcase(item.title), String.downcase(query))
        end)
      end

    socket =
      socket
      |> assign(:filtered_items, filtered_items)
      |> assign(:search_query, query)

    {:noreply, socket}
  end

  def handle_event("select_item", %{"index" => index}, socket) do
    case parse_index(index) do
      {:ok, idx} ->
        case Enum.at(socket.assigns.filtered_items, idx) do
          nil ->
            {:noreply, socket}

          item ->
            navigate_to_item(socket, item)
        end

      :error ->
        {:noreply, socket}
    end
  end

  attr(:items, :list, required: true)
  attr(:current_item_resource_id, :any, required: true)
  attr(:path_builder_fn, :fun, required: true)
  attr(:navigation_type, :atom, default: :navigate, values: [:navigate, :patch])

  # A single-item navigator is intentionally non-interactive: there is no alternate
  # selection to choose, so we render the current label without dropdown or arrows.
  def render(%{all_items: [_single_item]} = assigns) do
    ~H"""
    <div class="inline-flex justify-start items-center">
      <div class="max-w-96 border-b-2 border-Fill-Buttons-fill-primary flex flex-col relative">
        <div class="w-[465px] px-2 py-1 rounded-md inline-flex flex-row justify-center items-center">
          <div
            class="w-full text-center justify-center items-center text-Text-text-high text-2xl font-bold truncate"
            title={if @current_item, do: @current_item.title, else: ""}
          >
            {if @current_item,
              do: item_title(@current_item_label, @current_item),
              else: "No item selected"}
          </div>
        </div>
      </div>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="inline-flex justify-start items-center">
      <p class="sr-only" role="status" aria-live="polite">
        {a11y_selection_announcement(@current_item_label, @current_item)}
      </p>
      <p class="sr-only" role="status" aria-live="polite">
        {a11y_dashboard_updated_announcement(@current_item_label, @current_item)}
      </p>
      <%= if @previous_item do %>
        <.nav_link
          role="previous item link"
          destination={@path_builder_fn.(@previous_item)}
          navigation_type={@navigation_type}
          class="px-4 py-2 rounded-md flex justify-center items-center gap-2"
        >
          <div class="pr-2 flex justify-end items-center gap-2 text-Text-text-button opacity-90">
            <Icons.left_chevron class="w-4 h-4 stroke-Text-text-button fill-none" />
            <div class="text-right justify-center text-xs font-semibold font-['Open_Sans'] leading-none whitespace-nowrap">
              Previous {resource_label(@previous_item)}
            </div>
          </div>
        </.nav_link>
      <% else %>
        <div
          role="previous item link disabled"
          class="px-4 py-2 rounded-md flex justify-center items-center gap-2 cursor-not-allowed"
        >
          <div class="pr-2 flex justify-end items-center gap-2 text-gray-400 opacity-50">
            <Icons.left_chevron class="w-4 h-4 stroke-gray-400/50 fill-none" />
            <div class="text-right justify-center text-xs font-semibold font-['Open_Sans'] leading-none whitespace-nowrap">
              Previous {@current_item_label}
            </div>
          </div>
        </div>
      <% end %>
      <div class="max-w-96 border-b-2 border-Fill-Buttons-fill-primary flex flex-col relative">
        <button
          phx-click={
            JS.toggle(
              to: "#searchable_dropdown",
              display: "inline-flex",
              in: {"ease-out duration-300", "opacity-0", "opacity-100"},
              out: {"ease-out duration-200", "opacity-100", "opacity-0"}
            )
            |> JS.push("search", value: %{value: ""}, target: @myself)
            |> JS.focus(to: "#search_input")
          }
          aria-haspopup="listbox"
          aria-controls="searchable_dropdown"
          class="w-[465px] px-2 py-1 rounded-md inline-flex flex-row justify-center items-center"
        >
          <div
            class="w-full text-center justify-center items-center text-Text-text-high text-2xl font-bold truncate"
            title={if @current_item, do: @current_item.title, else: ""}
          >
            {if @current_item,
              do: item_title(@current_item_label, @current_item),
              else: "No item selected"}
          </div>
          <div class="self-end">
            <Icons.chevron_down width="24" height="24" />
          </div>
        </button>
        <.searchable_dropdown
          filtered_items={@filtered_items}
          current_item_resource_id={if @current_item, do: @current_item.resource_id, else: nil}
          current_item_label={@current_item_label}
          search_query={@search_query}
          target={@myself}
        />
      </div>
      <%= if @next_item do %>
        <.nav_link
          destination={@path_builder_fn.(@next_item)}
          navigation_type={@navigation_type}
          role="next item link"
          class="px-4 py-2 rounded-md flex justify-center items-center gap-2"
        >
          <div class="pl-2 flex justify-center items-center gap-2 text-Text-text-button opacity-90">
            <div class="text-right justify-center text-xs font-semibold font-['Open_Sans'] leading-none whitespace-nowrap">
              Next {resource_label(@next_item)}
            </div>
            <Icons.chevron_right width="24" height="24" />
          </div>
        </.nav_link>
      <% else %>
        <div
          role="next item link disabled"
          class="px-4 py-2 rounded-md flex justify-center items-center gap-2 cursor-not-allowed"
        >
          <div class="pl-2 flex justify-center items-center gap-2 text-gray-400 opacity-50">
            <div class="text-right justify-center text-xs font-semibold font-['Open_Sans'] leading-none whitespace-nowrap">
              Next {@current_item_label}
            </div>
            <Icons.chevron_right width="24" height="24" />
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  attr(:filtered_items, :list, required: true)
  attr(:current_item_resource_id, :any, required: true)
  attr(:current_item_label, :string, required: true)
  attr(:search_query, :string, required: true)
  attr(:target, :any, required: true)

  def searchable_dropdown(assigns) do
    ~H"""
    <div
      id="searchable_dropdown"
      role="listbox"
      phx-hook="ListNavigatorDropdown"
      phx-click-away={JS.hide(transition: {"ease-out duration-200", "opacity-100", "opacity-0"})}
      class="hidden absolute top-full left-1/2 transform -translate-x-1/2 z-50 w-[465px] pb-1.5 bg-Background-bg-secondary rounded shadow-[0px_0px_8px_0px_rgba(0,0,0,0.15)] flex-col justify-center items-start overflow-hidden"
    >
      <div class="border-b-0.5 border-Border-border-primary/80 self-stretch pl-9 pr-4 py-1.5 mb-3 bg-Background-bg-secondary shadow-[0px_1px_0px_0px_rgba(245,245,245,1.00)] inline-flex justify-start items-center">
        <div class="w-5 h-5 relative">
          <i class="fa-solid fa-search text-Icon-icon-default pointer-events-none text-lg"></i>
        </div>
        <input
          id="search_input"
          type="text"
          name="list_navigator_search"
          placeholder="Search"
          value={@search_query}
          autocomplete="off"
          autocorrect="off"
          autocapitalize="off"
          spellcheck="false"
          phx-keyup="search"
          phx-debounce="300"
          phx-target={@target}
          class="flex-1 bg-Background-bg-secondary text-Text-text-low text-sm font-semibold leading-none placeholder-Text-text-low border-none focus:border-none focus:ring-0 focus:ring-offset-0 outline-none focus:outline-none"
        />
      </div>
      <div class="inline-flex flex-col overflow-y-scroll max-h-56 w-full">
        <%= if Enum.empty?(@filtered_items) and String.trim(@search_query) != "" do %>
          <div class="w-full px-4 py-8 text-center">
            <div class="text-Text-text-low text-sm font-medium font-['Open_Sans'] leading-none">
              No results found for <span class="italic font-bold">"{@search_query}"</span>
            </div>
          </div>
        <% else %>
          <button
            :for={{item, index} <- Enum.with_index(@filtered_items)}
            phx-click={
              JS.push("select_item", value: %{index: index}, target: @target)
              |> JS.hide(to: "#searchable_dropdown")
            }
            data-list-navigator-option="true"
            data-list-navigator-current={to_string(item.resource_id == @current_item_resource_id)}
            role="option"
            aria-selected="false"
            class={[
              "w-full cursor-pointer self-stretch px-2 py-1.5 inline-flex justify-between items-center",
              if(item.resource_id == @current_item_resource_id,
                do: "bg-Fill-Buttons-fill-primary text-white",
                else: "bg-Background-bg-secondary"
              )
            ]}
          >
            <div class="flex justify-start items-center gap-1 flex-1 min-w-0">
              <div class="p-1 opacity-0 flex justify-center items-center gap-2.5">
                <div class="w-4 h-4 relative overflow-hidden">
                  <div class="w-4 h-4 left-0 top-0 absolute"></div>
                  <div class="w-3 h-2 left-[2.27px] top-[3.73px] absolute bg-neutral-700"></div>
                </div>
              </div>
              <div class="flex justify-start items-center gap-1 flex-1 min-w-0">
                <div class="flex justify-start items-center gap-2.5 overflow-hidden flex-1 min-w-0">
                  <div
                    class={[
                      "justify-center text-sm font-medium font-['Open_Sans'] leading-none truncate min-w-0",
                      if(item.resource_id == @current_item_resource_id,
                        do: "text-Buttons-fill-primary",
                        else: "text-Text-text-high"
                      )
                    ]}
                    title={item.title}
                  >
                    {item_prefix(resource_label(item), item)}
                    {Phoenix.HTML.raw(
                      Utils.highlight_search_term(item.title, @search_query,
                        class: "bg-yellow-200 dark:bg-yellow-700 font-semibold"
                      )
                    )}
                  </div>
                </div>
              </div>
            </div>
            <div class="pr-4 flex justify-end items-center gap-0.5"></div>
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  attr(:destination, :string, required: true)
  attr(:navigation_type, :atom, required: true, values: [:navigate, :patch])
  attr(:role, :string, default: nil)
  attr(:class, :string, default: nil)
  slot(:inner_block, required: true)

  defp nav_link(%{navigation_type: :navigate} = assigns) do
    ~H"""
    <.link navigate={@destination} role={@role} class={@class}>
      {render_slot(@inner_block)}
    </.link>
    """
  end

  defp nav_link(assigns) do
    ~H"""
    <.link patch={@destination} role={@role} class={@class}>
      {render_slot(@inner_block)}
    </.link>
    """
  end

  defp resource_label(resource) do
    page_type_id = Oli.Resources.ResourceType.get_id_by_type("page")
    container_type_id = Oli.Resources.ResourceType.get_id_by_type("container")

    case {resource.resource_type_id, resource.numbering_level} do
      {^page_type_id, _} -> "Page"
      {^container_type_id, 0} -> ""
      {^container_type_id, 1} -> "Unit"
      {^container_type_id, 2} -> "Module"
      {^container_type_id, 3} -> "Section"
    end
  end

  defp item_prefix("Page", _item), do: ""
  defp item_prefix(_label, %{numbering_index: -1} = _item), do: ""
  defp item_prefix(label, item), do: "#{label} #{item.numbering_index}: "

  # We use -1 to detect the default dropdown item ("All Modules" for example)
  defp item_title(_label, %{numbering_index: -1} = item), do: item.title
  defp item_title("Page", item), do: item.title

  defp item_title(label, item) do
    "#{item_prefix(label, item)}#{item.title}"
  end

  defp searchable_items(items, nil), do: items

  defp searchable_items(items, current_item) do
    Enum.reject(items, fn item -> item.resource_id == current_item.resource_id end)
  end

  defp close_dropdown(socket) do
    assign(socket,
      search_query: "",
      filtered_items: socket.assigns.all_items
    )
  end

  defp parse_index(index) do
    case Integer.parse(to_string(index)) do
      {parsed, ""} when parsed >= 0 -> {:ok, parsed}
      _ -> :error
    end
  end

  defp navigate_to_item(socket, item) do
    destination = socket.assigns.path_builder_fn.(item)
    socket = close_dropdown(socket)

    case socket.assigns.navigation_type do
      :patch -> {:noreply, push_patch(socket, to: destination)}
      :navigate -> {:noreply, push_navigate(socket, to: destination)}
    end
  end

  defp a11y_selection_announcement("", _), do: ""
  defp a11y_selection_announcement(_, nil), do: ""

  defp a11y_selection_announcement(label, item) do
    "Filtered to #{item_title(label, item)}"
  end

  defp a11y_dashboard_updated_announcement("", _), do: ""
  defp a11y_dashboard_updated_announcement(_, nil), do: ""

  defp a11y_dashboard_updated_announcement(label, item) do
    "Dashboard content updated for #{item_title(label, item)}"
  end
end
