defmodule OliWeb.Components.Delivery.ListNavigator do
  @moduledoc """
  A component that allows the user to navigate through a list of items.
  Renders the current item with previous/next controls, and a searchable dropdown for direct selection.

  Items can be of type page, unit, module, or section.
  """

  use OliWeb, :live_component
  alias OliWeb.Icons

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
        current_item_label: resource_label(current_item),
        previous_item: previous_item,
        next_item: next_item,
        all_items: assigns.items,
        filtered_items: assigns.items,
        path_builder_fn: assigns.path_builder_fn,
        search_query: ""
      })

    {:ok, socket}
  end

  def handle_event("search", %{"value" => query}, socket) do
    # Filter out the current item from all items first
    available_items =
      socket.assigns.all_items
      |> Enum.reject(fn item -> item.resource_id == socket.assigns.current_item.resource_id end)

    filtered_items =
      if String.trim(query) == "" do
        available_items
      else
        available_items
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

  defp highlight_search_term(text, search_term) when search_term == "", do: text

  defp highlight_search_term(text, search_term) do
    # Use case-insensitive regex to find all matches
    regex = ~r/#{Regex.escape(search_term)}/i
    parts = String.split(text, regex, include_captures: true)

    parts
    |> Enum.with_index()
    |> Enum.map(fn
      {part, index} when rem(index, 2) == 0 ->
        part

      {part, _} ->
        [~s(<span class="bg-yellow-200 dark:bg-yellow-700 font-semibold">), part, ~s(</span>)]
    end)
    |> List.flatten()
    |> :erlang.iolist_to_binary()
  end

  attr(:items, :list, required: true)
  attr(:current_item_resource_id, :integer, required: true)
  attr(:path_builder_fn, :fun, required: true)

  def render(assigns) do
    ~H"""
    <div class="inline-flex justify-start items-center">
      <%= if @previous_item do %>
        <.link
          navigate={@path_builder_fn.(@previous_item)}
          class="px-4 py-2 rounded-md flex justify-center items-center gap-2"
        >
          <div class="pr-2 flex justify-end items-center gap-2 text-Text-text-button opacity-90">
            <Icons.chevron_left width="24" height="24" />
            <div class="text-right justify-center text-xs font-semibold font-['Open_Sans'] leading-none whitespace-nowrap">
              Previous {@current_item_label}
            </div>
          </div>
        </.link>
      <% else %>
        <div class="px-4 py-2 rounded-md flex justify-center items-center gap-2 cursor-not-allowed">
          <div class="pr-2 flex justify-end items-center gap-2 text-gray-400 opacity-50">
            <Icons.chevron_left width="24" height="24" />
            <div class="text-right justify-center text-xs font-semibold font-['Open_Sans'] leading-none whitespace-nowrap">
              Previous {@current_item_label}
            </div>
          </div>
        </div>
      <% end %>
      <div class="max-w-96 border-b-2 border-Fill-Buttons-fill-primary flex flex-col relative">
        <button
          data-direction="Vertical"
          data-is-link="False"
          data-number="1"
          data-state="Default"
          phx-click={
            JS.toggle(
              to: "#searchable_dropdown",
              display: "inline-flex",
              in: {"ease-out duration-300", "opacity-0", "opacity-100"},
              out: {"ease-out duration-200", "opacity-100", "opacity-0"}
            )
            |> JS.focus(to: "#search_input")
          }
          class="w-[465px] px-2 py-1 rounded-md inline-flex flex-row justify-center items-center"
        >
          <div
            class="w-full text-center justify-center items-center text-Text-text-high text-2xl font-bold truncate"
            title={@current_item.title}
          >
            {item_title(@current_item_label, @current_item)}
          </div>
          <div class="self-end">
            <Icons.chevron_down width="24" height="24" />
          </div>
        </button>
        <.searchable_dropdown
          filtered_items={@filtered_items}
          current_item_resource_id={@current_item.resource_id}
          current_item_label={@current_item_label}
          path_builder_fn={@path_builder_fn}
          search_query={@search_query}
          target={@myself}
        />
      </div>
      <%= if @next_item do %>
        <.link
          navigate={@path_builder_fn.(@next_item)}
          class="px-4 py-2 rounded-md flex justify-center items-center gap-2"
        >
          <div class="pl-2 flex justify-center items-center gap-2 text-Text-text-button opacity-90">
            <div class="text-right justify-center text-xs font-semibold font-['Open_Sans'] leading-none whitespace-nowrap">
              Next {@current_item_label}
            </div>
            <Icons.chevron_right width="24" height="24" />
          </div>
        </.link>
      <% else %>
        <div class="px-4 py-2 rounded-md flex justify-center items-center gap-2 cursor-not-allowed">
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

  def searchable_dropdown(assigns) do
    ~H"""
    <div
      id="searchable_dropdown"
      phx-click-away={JS.hide(transition: {"ease-out duration-200", "opacity-100", "opacity-0"})}
      class="hidden absolute top-full left-1/2 transform -translate-x-1/2 z-20 w-[465px] pb-1.5 bg-Background-bg-secondary rounded shadow-[0px_0px_8px_0px_rgba(0,0,0,0.15)] flex-col justify-center items-start overflow-hidden"
    >
      <div
        data-chevron="No"
        data-hover="No"
        data-icon="Yes"
        data-keyboard-shortcut="No"
        data-menu-cell-type="Search"
        data-selected="No"
        class="border-b-0.5 border-Border-border-primary/80 self-stretch pl-9 pr-4 py-1.5 mb-3 bg-Background-bg-secondary shadow-[0px_1px_0px_0px_rgba(245,245,245,1.00)] inline-flex justify-start items-center"
      >
        <div class="w-5 h-5 relative">
          <i class="fa-solid fa-search text-Icon-icon-default pointer-events-none text-lg"></i>
        </div>
        <input
          id="search_input"
          type="text"
          placeholder="Search"
          value={@search_query}
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
            :for={item <- @filtered_items}
            data-chevron="No"
            data-hover="No"
            data-icon="No"
            data-keyboard-shortcut="No"
            data-menu-cell-type="Option"
            phx-click={JS.navigate(@path_builder_fn.(item))}
            class={[
              "w-full cursor-pointer self-stretch px-2 py-1.5 inline-flex justify-between items-center",
              if(item.resource_id == @current_item_resource_id,
                do: "bg-Fill-Buttons-fill-primary text-white",
                else: "bg-Background-bg-secondary hover:bg-Background-bg-primary"
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
                <div
                  data-property-1="Default"
                  class="flex justify-start items-center gap-2.5 overflow-hidden flex-1 min-w-0"
                >
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
                    {item_prefix(@current_item_label, item)}
                    {Phoenix.HTML.raw(highlight_search_term(item.title, @search_query))}
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

  defp resource_label(resource) do
    page_type_id = Oli.Resources.ResourceType.get_id_by_type("page")
    container_type_id = Oli.Resources.ResourceType.get_id_by_type("container")

    case {resource.resource_type_id, resource.numbering_level} do
      {type, _} when type == page_type_id -> "Page"
      {type, 1} when type == container_type_id -> "Unit"
      {type, 2} when type == container_type_id -> "Module"
      {type, 3} when type == container_type_id -> "Section"
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
end
