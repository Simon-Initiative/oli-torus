defmodule OliWeb.Delivery.Student.Lesson.Components.OutlineComponent do
  use OliWeb, :live_component

  alias Oli.Resources.ResourceType
  alias OliWeb.Icons
  alias OliWeb.Delivery.Student.Utils

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
  attr :section_slug, :string, required: true
  attr :selected_view, :atom, required: true
  attr :expanded_items, :list, default: []

  def render(assigns) do
    ~H"""
    <div class="h-full max-h-screen w-[360px] px-2 py-4 bg-white mx-2 rounded-2xl shadow flex-col justify-start items-start gap-6 inline-flex">
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
      <div class="h-fit max-h-screen pl-2 overflow-y-auto pl-2 justify-start items-start gap-2 inline-flex">
        <div class="grow shrink basis-0 self-stretch px-2 flex-col justify-start items-center gap-4 inline-flex">
          <.outline_item
            :for={node <- @hierarchy["children"]}
            item={node}
            is_container?={node["resource_type_id"] == ResourceType.id_for_container()}
            expanded_items={@expanded_items}
            target={@myself}
            section_slug={@section_slug}
            selected_view={@selected_view}
          />
        </div>
      </div>
    </div>
    """
  end

  attr :item, :map, required: true
  attr :is_container?, :boolean, required: true
  attr :expanded_items, :list, required: true
  attr :target, :any, required: true
  attr :section_slug, :string, required: true
  attr :selected_view, :atom, required: true

  def outline_item(%{item: %{"numbering" => %{"level" => level}}}) when level > 3, do: nil

  def outline_item(%{is_container?: false} = assigns) do
    ~H"""
    <% resource_path =
      Utils.lesson_live_path(@section_slug, @item["section_resource"].revision_slug,
        request_path:
          Utils.learn_live_path(@section_slug,
            target_resource_id: @item["resource_id"],
            selected_view: @selected_view
          ),
        selected_view: @selected_view
      ) %>
    <.link
      href={resource_path}
      class="w-full text-black dark:text-white hover:text-black dark:hover:text-white hover:cursor-pointer hover:no-underline"
    >
      <div class={[
        "justify-start items-start flex py-1 rounded-lg hover:bg-[#f2f8ff]",
        left_indentation(@item["numbering"]["level"])
      ]}>
        <div class="grow p-2 justify-start items-start gap-5 flex">
          <div class="py-0.5 justify-start items-center gap-5 flex">
            <div class="justify-start items-center flex">
              <div class="w-5 h-5 relative">
                <.page_icon graded={@item["graded"]} purpose={@item["section_resource"].purpose} />
              </div>
            </div>
            <div class="justify-start items-center flex">
              <div class="grow shrink basis-0 text-right text-sm leading-none">
                <%= @item["numbering"]["index"] %>
              </div>
            </div>
          </div>
          <div class="grow flex-col justify-start items-start gap-2 flex">
            <div class="justify-start items-start gap-5 flex">
              <div class="grow justify-start items-center flex">
                <div class={[
                  "grow text-base leading-normal",
                  if(@item["graded"], do: "font-semibold")
                ]}>
                  <%= @item["title"] %>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </.link>
    """
  end

  def outline_item(assigns) do
    ~H"""
    <% expanded? = Integer.to_string(@item["id"]) in @expanded_items %>
    <div class={[
      "self-stretch flex-col justify-start items-start gap-2 inline-flex",
      left_indentation(@item["numbering"]["level"])
    ]}>
      <div
        phx-click="expand_item"
        phx-value-item_id={@item["id"]}
        phx-target={@target}
        class="w-full grow shrink basis-0 p-2 flex-col justify-start items-start gap-1 inline-flex rounded-lg hover:bg-[#f2f8ff] hover:cursor-pointer"
      >
        <div class="self-stretch justify-start items-start gap-1 inline-flex">
          <div>
            <%= if expanded? do %>
              <Icons.chevron_down width="20" height="20" />
            <% else %>
              <Icons.chevron_right width="20" height="20" />
            <% end %>
          </div>

          <div class="grow shrink basis-0 text-[#353740] text-base font-bold leading-normal">
            <%= resource_label(@item) %>
            <%= @item["title"] %>
          </div>
        </div>
      </div>
      <div
        :if={expanded?}
        class="grow shrink basis-0 py-1 flex-col justify-start items-start gap-1 inline-flex"
      >
        <.outline_item
          :for={node <- @item["children"]}
          item={node}
          expanded_items={@expanded_items}
          is_container?={node["resource_type_id"] == ResourceType.id_for_container()}
          target={@target}
          section_slug={@section_slug}
          selected_view={@selected_view}
        />
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

  defp no_icon(assigns) do
    ~H"""
    <div role="no icon" class="flex justify-center items-center w-[22px] h-[22px] shrink-0"></div>
    """
  end

  defp resource_label(%{"resource_type_id" => resource_type_id} = resource) do
    container_id = ResourceType.id_for_container()

    if resource_type_id == container_id do
      get_numbering_label(resource["numbering"]["labels"], resource["numbering"]["level"]) <>
        " #{resource["numbering"]["index"]}: "
    else
      nil
    end
  end

  defp get_numbering_label(labels, level) do
    case level do
      1 -> labels[:unit] || "Unit"
      2 -> labels[:module] || "Module"
      _ -> labels[:section] || "Section"
    end
  end

  defp left_indentation(numbering_level) do
    case numbering_level do
      2 -> "ml-[20px]"
      3 -> "ml-[40px]"
      _ -> "ml-0"
    end
  end

  attr(:graded, :boolean, required: true)
  attr(:purpose, :atom, required: true)

  defp page_icon(assigns) do
    ~H"""
    <div class="w-fit shrink-0">
      <%= cond do %>
        <% @purpose == :application -> %>
          <div class="text-exploration dark:text-exploration-dark">
            <Icons.world />
          </div>
        <% @graded -> %>
          <div class="text-checkpoint dark:text-checkpoint-dark">
            <Icons.flag />
          </div>
        <% true -> %>
          <.no_icon />
      <% end %>
    </div>
    """
  end
end
