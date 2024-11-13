defmodule OliWeb.Delivery.Student.Lesson.Components.OutlineComponent do
  use OliWeb, :live_component

  alias Oli.Resources.ResourceType
  alias OliWeb.Icons
  alias OliWeb.Delivery.Student.Utils
  alias Oli.Delivery.{Hierarchy, Metrics}
  alias OliWeb.Components.Common

  def mount(socket) do
    {:ok,
     socket
     |> assign(expanded_items: [])}
  end

  def update(assigns, socket) do
    item_with_progress =
      case Hierarchy.find_top_level_ancestor(assigns.hierarchy, assigns.page_resource_id) do
        nil ->
          # It is a top level page
          page_progress =
            Metrics.progress_for_page(
              assigns.section_id,
              assigns.user_id,
              assigns.page_resource_id
            )
            |> parse_progress()

          %{progress: page_progress, resource_id: assigns.page_resource_id}

        container ->
          container_progress =
            Metrics.progress_for(assigns.section_id, assigns.user_id, container["resource_id"])
            |> parse_progress()

          %{progress: container_progress, resource_id: container["resource_id"]}
      end

    {:ok,
     socket
     |> assign(:hierarchy, assigns.hierarchy)
     |> assign(:section_slug, assigns.section_slug)
     |> assign(:selected_view, assigns.selected_view)
     |> assign(:item_with_progress, item_with_progress)}
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
  attr :item_with_progress, :map, required: true
  attr :expanded_items, :list, default: []

  def render(assigns) do
    ~H"""
    <div
      id="outline_panel"
      class="flex flex-col w-[360px] h-full max-h-[calc(100vh-96px)] px-2 py-4 bg-white dark:bg-black text-[#353740] dark:text-[#eeebf5] mx-2 rounded-2xl gap-6"
    >
      <button
        phx-click="toggle_outline_sidebar"
        class="self-stretch px-2 justify-end items-center gap-2.5 inline-flex hover:cursor-pointer"
      >
        <i class="fa-solid fa-xmark hover:scale-110"></i>
      </button>
      <div class="self-stretch h-12 px-2 flex-col justify-start items-start gap-4 flex">
        <div class="self-stretch py-2 justify-start items-center inline-flex">
          <div class="text-base font-bold leading-none">
            Course Content
          </div>
        </div>
        <div class="self-stretch h-0 flex-col justify-center items-center flex border-b border-[#D9D9D9]/75">
        </div>
      </div>
      <div class="flex flex-1 flex-col overflow-hidden pl-2 justify-start items-start gap-2 inline-flex">
        <div class="flex flex-1 flex-col overflow-y-scroll px-2 justify-start items-center gap-4 inline-flex">
          <.outline_item
            :for={node <- @hierarchy["children"]}
            item={node}
            is_container?={node["resource_type_id"] == ResourceType.id_for_container()}
            expanded_items={@expanded_items}
            target={@myself}
            section_slug={@section_slug}
            selected_view={@selected_view}
            progress={
              if @item_with_progress.resource_id == node["resource_id"],
                do: @item_with_progress.progress
            }
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
  attr :progress, :float, default: nil

  def outline_item(%{item: %{"numbering" => %{"level" => level}}}) when level > 3, do: nil

  def outline_item(%{is_container?: false} = assigns) do
    ~H"""
    <% resource_path =
      Utils.lesson_live_path(@section_slug, @item["slug"],
        request_path:
          Utils.learn_live_path(@section_slug,
            target_resource_id: @item["resource_id"],
            selected_view: @selected_view
          ),
        selected_view: @selected_view
      ) %>
    <.link
      id={"outline_item_#{@item["id"]}"}
      href={resource_path}
      class="w-full text-[#353740] dark:text-[#eeebf5] hover:text-[#353740] dark:hover:text-[#eeebf5] hover:cursor-pointer hover:no-underline"
    >
      <div class={[
        "justify-start items-start flex py-1 rounded-lg hover:bg-[#f2f8ff] dark:hover:bg-[#2e2b33]",
        left_indentation(@item["numbering"]["level"]),
        if(@progress, do: "bg-[#f3f4f8] dark:bg-[#1b191f]")
      ]}>
        <div class="grow p-2 justify-start items-start gap-5 flex">
          <div class="py-0.5 justify-start items-center gap-5 flex">
            <div class="justify-start items-center flex" role="page icon">
              <div class="w-5 h-5 relative">
                <.page_icon graded={@item["graded"]} purpose={@item["section_resource"].purpose} />
              </div>
            </div>
            <div class="justify-start items-center flex" role="index">
              <div class="grow shrink basis-0 text-right text-sm leading-none">
                <%= @item["numbering"]["index"] %>
              </div>
            </div>
          </div>
          <div class="grow flex-col justify-start items-start gap-2 flex">
            <div class="justify-start items-start gap-5 flex" role="title">
              <div class="grow justify-start items-center flex">
                <div class={[
                  "grow text-base leading-normal",
                  if(@item["graded"], do: "font-semibold")
                ]}>
                  <%= @item["title"] %>
                </div>
              </div>
            </div>
            <Common.progress_bar
              :if={@progress}
              percent={@progress}
              width="200px"
              on_going_colour="bg-[#0CAF61]"
              completed_colour="bg-[#0CAF61]"
              role="progress bar"
            />
          </div>
        </div>
      </div>
    </.link>
    """
  end

  def outline_item(assigns) do
    ~H"""
    <% expanded? = Integer.to_string(@item["id"]) in @expanded_items %>
    <div
      id={"outline_item_#{@item["id"]}"}
      class={[
        "self-stretch flex-col justify-start items-start gap-2 inline-flex",
        left_indentation(@item["numbering"]["level"])
      ]}
    >
      <div
        phx-click="expand_item"
        phx-value-item_id={@item["id"]}
        phx-target={@target}
        class={[
          "w-full grow shrink basis-0 p-2 flex-col justify-start items-start gap-1 inline-flex rounded-lg hover:bg-[#f2f8ff] dark:hover:bg-[#2e2b33] hover:cursor-pointer",
          if(@progress, do: "bg-[#f3f4f8] dark:bg-[#1b191f]")
        ]}
      >
        <div class="text-[#353740] dark:text-[#eeebf5] self-stretch justify-start items-start gap-1 inline-flex">
          <div>
            <%= if expanded? do %>
              <Icons.chevron_down width="20" height="20" />
            <% else %>
              <Icons.chevron_right width="20" height="20" />
            <% end %>
          </div>

          <div class="grow shrink basis-0 text-base font-bold leading-normal" role="title">
            <%= resource_label(@item) %>
            <%= @item["title"] %>
          </div>
        </div>
        <Common.progress_bar
          :if={@progress}
          percent={@progress}
          width="200px"
          on_going_colour="bg-[#0CAF61]"
          completed_colour="bg-[#0CAF61]"
          role="progress bar"
        />
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

  attr :is_active, :boolean, required: true
  slot :inner_block, required: true

  def toggle_outline_button(assigns) do
    ~H"""
    <button
      class={[
        "flex flex-col items-center rounded-lg bg-white dark:bg-black hover:bg-[#deecff] dark:hover:bg-white/10 text-[#0d70ff] text-xl group",
        if(@is_active,
          do:
            "!text-white bg-[#0080ff] dark:bg-[#0062f2] hover:bg-[#0080ff]/75 hover:dark:bg-[#0062f2]/75"
        )
      ]}
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
      fill="currentColor"
      xmlns="http://www.w3.org/2000/svg"
    >
      <g clip-path="url(#clip0_2001_36964)">
        <path
          d="M13.0833 11H22.25M13.0833 15.9958H22.25M13.0833 20.9917H22.25M9.75 11V11.0083M9.75 15.9958V16.0042M9.75 20.9917V21"
          stroke="currentColor"
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
          <Icons.no_icon />
      <% end %>
    </div>
    """
  end

  defp parse_progress(progress) do
    progress
    |> Kernel.*(100)
    |> round()
    |> trunc()
  end
end
