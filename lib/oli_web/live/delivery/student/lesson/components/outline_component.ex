defmodule OliWeb.Delivery.Student.Lesson.Components.OutlineComponent do
  use OliWeb, :live_component

  def mount(socket) do
    {:ok,
     socket
     |> assign(expanded_items: [])}
  end

  def handle_event("expand_item", %{"item_id" => item_id}, socket) do
    expanded_items =
      if item_id in socket.assigns.expanded_items do
        List.delete(socket.assigns.expanded_items, item_id)
      else
        [item_id | socket.assigns.expanded_items]
      end

    {:noreply, assign(socket, expanded_items: expanded_items)}
  end

  attr :hierarchy, :map, required: true
  attr :expanded_items, :list, default: []

  def render(assigns) do
    ~H"""
    <div class="h-fit w-[360px] px-2 py-4 bg-white mx-2 rounded-2xl shadow flex-col justify-start items-start gap-6 inline-flex">
      <div
        phx-click="toggle_outline_sidebar"
        class="self-stretch px-2 justify-end items-center gap-2.5 inline-flex hover:cursor-pointer"
      >
        <i class="fa-solid fa-xmark hover:scale-110"></i>
      </div>
      <div class="self-stretch h-12 px-2 flex-col justify-start items-start gap-4 flex">
        <div class="self-stretch py-2 justify-start items-center inline-flex">
          <div class="text-[#353740] text-base font-bold leading-none">
            Course Content
          </div>
        </div>
        <div class="self-stretch h-0 flex-col justify-center items-center flex border-b border-[#D9D9D9]/75">
        </div>
      </div>
      <div class="self-stretch grow shrink basis-0 pl-2 justify-start items-start gap-2 inline-flex">
        <div class="grow shrink basis-0 self-stretch px-2 flex-col justify-start items-center gap-4 inline-flex">
          <div
            :for={node <- @hierarchy["children"]}
            phx-click="expand_item"
            phx-value-item_id={node["id"]}
            phx-target={@myself}
            class="self-stretch py-1 justify-start items-start gap-2 inline-flex rounded-lg hover:bg-[#f3f4f8]/50 hover:cursor-pointer"
          >
            <div class="grow shrink basis-0 py-1 flex-col justify-start items-start gap-1 inline-flex">
              <div class="self-stretch justify-start items-start gap-1 inline-flex">
                <%= if Integer.to_string(node["id"]) in @expanded_items do %>
                  <OliWeb.Icons.chevron_down width="20" height="20" />
                <% else %>
                  <OliWeb.Icons.chevron_right width="20" height="20" />
                <% end %>
                <div class="grow shrink basis-0 text-[#353740] text-base font-bold leading-normal">
                  <%= resource_label(node) %>
                  <%= node["title"] %>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def toggle_outline_button(assigns) do
    ~H"""
    <button
      class="flex flex-col items-center rounded-l-lg bg-white dark:bg-black text-xl group"
      phx-click="toggle_outline_sidebar"
    >
      <div class="p-1.5 rounded justify-start items-center gap-2.5 inline-flex">
        <%= render_slot(@inner_block) %>
      </div>
    </button>
    """
  end

  def outline_icon(assigns) do
    ~H"""
    <svg
      width="32"
      height="32"
      viewBox="0 0 32 32"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      class="group-hover:scale-110"
    >
      <g clip-path="url(#clip0_2001_36964)">
        <path
          d="M13.0833 11H22.25M13.0833 15.9958H22.25M13.0833 20.9917H22.25M9.75 11V11.0083M9.75 15.9958V16.0042M9.75 20.9917V21"
          stroke="#0D70FF"
          stroke-width="1.5"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </g>
      <defs>
        <clipPath id="clip0_2001_36964">
          <rect width="20" height="20" fill="white" transform="translate(6 6)" />
        </clipPath>
      </defs>
    </svg>
    """
  end

  defp resource_label(%{"resource_type_id" => 2} = resource) do
    get_numbering_label(resource["numbering"]["labels"], resource["numbering"]["level"]) <>
      " #{resource["numbering"]["index"]}: "
  end

  defp resource_label(_resource), do: nil

  defp get_numbering_label(labels, level) do
    case level do
      1 -> labels[:unit] || "Unit"
      2 -> labels[:module] || "Module"
      _ -> labels[:section] || "Section"
    end
  end
end
