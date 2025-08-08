defmodule OliWeb.Components.Delivery.CourseContent do
  use Phoenix.LiveComponent

  alias Oli.Delivery.Metrics
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Components.Delivery.Buttons
  alias OliWeb.Components.Delivery.Utils, as: DeliveryUtils
  alias Oli.Resources.Numbering

  attr(:breadcrumbs_tree, :map, required: true)
  attr(:current_position, :integer, required: true)
  attr(:current_level_nodes, :list, required: true)
  attr(:section, :map, required: true)
  attr(:current_user_id, :integer)
  attr(:current_level, :integer)
  attr(:scheduled_dates, :list, required: true)
  attr(:event_target, :string, default: nil)
  attr(:is_instructor, :boolean, default: false)
  attr(:preview_mode, :boolean, default: false)

  def adjust_hierarchy_for_only_pages(hierarchy) do
    case Enum.all?(hierarchy["children"], fn child -> child["type"] == "page" end) do
      true ->
        %{
          "children" => [
            %{
              "graded" => "false",
              "id" => "0",
              "index" => "0",
              # The course content browser handles case of the special level of -1
              "level" => "-1",
              "next" => nil,
              "prev" => nil,
              "slug" => nil,
              "title" => "Curriculum",
              "type" => "container",
              "children" => hierarchy["children"]
            }
          ]
        }

      _ ->
        hierarchy
    end
  end

  def render(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-800 shadow-sm">
      <div class="flex flex-col divide-y divide-gray-100 dark:divide-gray-700">
        <section class="flex flex-col p-8">
          <h4 class="text-base font-semibold mr-auto tracking-wide text-gray-800 dark:text-white h-8">
            Course Content
          </h4>
          <span class="text-sm font-normal tracking-wide text-gray-800 dark:text-white mt-2">
            Find all your course content, material, assignments and class activities here.
          </span>
        </section>
        <%= if get_current_node(@current_level_nodes, @current_position)["level"] != "-1" do %>
          <section class="flex flex-row justify-between p-8">
            <div class="text-xs absolute -mt-5">
              {render_breadcrumbs(%{breadcrumbs_tree: @breadcrumbs_tree, myself: @myself})}
            </div>
            <button
              phx-click="previous_node"
              phx-target={@myself}
              class={if @current_position == 0, do: "grayscale pointer-events-none"}
            >
              <i class="fa-regular fa-circle-left text-primary text-xl"></i>
            </button>
            <div class="flex flex-col">
              <h4
                id="course_browser_node_title"
                class="text-lg font-semibold tracking-wide text-gray-800 dark:text-white mx-auto h-9"
              >
                {get_resource_name(
                  @current_level_nodes,
                  @current_position,
                  @section.display_curriculum_item_numbering,
                  @section.customizations
                )}
              </h4>
              <%= if !assigns[:is_instructor] do %>
                <div class="flex items-center justify-center space-x-3 mt-1">
                  <span class="uppercase text-[10px] tracking-wide text-gray-800 dark:text-white">
                    {"#{get_resource_prefix(get_current_node(@current_level_nodes, @current_position), @section.display_curriculum_item_numbering, @section.customizations)} overall progress"}
                  </span>
                  <div id="browser_overall_progress_bar" class="w-52 rounded-full bg-gray-200 h-2">
                    <div
                      class="rounded-full bg-primary h-2"
                      style={"width: #{get_current_node_progress(@current_level_nodes, @current_position, @current_user_id, @section.id)}%"}
                    >
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
            <button
              phx-click="next_node"
              phx-target={@myself}
              class={
                if @current_position + 1 == length(@current_level_nodes),
                  do: "grayscale pointer-events-none"
              }
            >
              <i class="fa-regular fa-circle-right text-primary text-xl"></i>
            </button>
          </section>
        <% end %>
        <%= for {resource, index} <- get_current_node(@current_level_nodes, @current_position)["children"] |> Enum.with_index() do %>
          <section class="flex flex-row justify-between items-center w-full p-8">
            <h4
              class={"text-sm font-bold tracking-wide text-gray-800 dark:text-white #{if resource["type"] == "container", do: "underline cursor-pointer"}"}
              phx-target={@myself}
              phx-click="go_down"
              phx-value-resource_id={resource["id"]}
              phx-value-selected_resource_index={index}
              phx-value-resource_type={resource["type"]}
            >
              {if resource["type"] == "container" and @section.display_curriculum_item_numbering,
                do:
                  "#{get_current_node(@current_level_nodes, @current_position)["index"]}.#{resource["index"]} #{resource["title"]}",
                else: resource["title"]}
            </h4>

            <%= if !assigns[:is_instructor] do %>
              <span class="w-64 h-10 text-sm tracking-wide text-gray-800 dark:text-white bg-gray-100 dark:bg-gray-500 rounded-sm flex justify-center items-center ml-auto mr-3">
                {DeliveryUtils.get_resource_scheduled_date(
                  String.to_integer(resource["id"]),
                  @scheduled_dates,
                  @ctx
                )}
              </span>
              <button
                class="torus-button primary h-10"
                phx-target={@myself}
                phx-click="open_resource"
                phx-value-resource_slug={resource["slug"]}
                phx-value-resource_type={resource["type"]}
                phx-value-preview={"#{@preview_mode}"}
              >
                Open
              </button>
            <% else %>
              <Buttons.button_with_options
                id={"open-resource-button-#{index}"}
                href={
                  Routes.page_delivery_path(
                    OliWeb.Endpoint,
                    preview_resource_type(resource["type"]),
                    @section.slug,
                    resource["slug"]
                  )
                }
                target="_blank"
                options={[
                  %{
                    text: "Open as student",
                    href:
                      Routes.page_delivery_path(
                        OliWeb.Endpoint,
                        String.to_existing_atom(resource["type"]),
                        @section.slug,
                        resource["slug"]
                      ),
                    target: "_blank"
                  }
                ]}
              >
                Open as instructor
              </Buttons.button_with_options>
            <% end %>
          </section>
        <% end %>
      </div>
    </div>
    """
  end

  def render_breadcrumbs(%{breadcrumbs_tree: []}), do: nil

  def render_breadcrumbs(assigns) do
    ~H"""
    <div class="flex flex-row space-x-2 divide-x divide-gray-100 dark:divide-gray-700">
      <%= for {target_level, target_position, text} <- Enum.take(@breadcrumbs_tree, 1) do %>
        <button
          phx-target={@myself}
          phx-click="breadcrumb-navigate"
          phx-value-target_level={target_level}
          phx-value-target_position={target_position}
        >
          {text}
        </button>
      <% end %>
      <%= for {target_level, target_position, text} <- Enum.drop(@breadcrumbs_tree, 1) do %>
        <span> > </span>
        <button
          phx-target={@myself}
          phx-click="breadcrumb-navigate"
          phx-value-target_level={target_level}
          phx-value-target_position={target_position}
        >
          {text}
        </button>
      <% end %>
    </div>
    """
  end

  def handle_event("next_node", _params, socket)
      when length(socket.assigns.current_level_nodes) == socket.assigns.current_position,
      do: {:noreply, socket}

  def handle_event(
        "next_node",
        _params,
        %{assigns: %{breadcrumbs_tree: current_breadcrumbs_tree}} = socket
      ) do
    {current_level, current_position, text} = List.last(current_breadcrumbs_tree)

    updated_breadcrumbs_tree =
      List.replace_at(
        current_breadcrumbs_tree,
        length(current_breadcrumbs_tree) - 1,
        {current_level, current_position + 1, text}
      )

    socket =
      socket
      |> update(:current_position, &(&1 + 1))
      |> assign(:breadcrumbs_tree, updated_breadcrumbs_tree)

    {:noreply, socket}
  end

  def handle_event("previous_node", _params, socket) when socket.assigns.current_position == 0,
    do: {:noreply, socket}

  def handle_event(
        "previous_node",
        _params,
        %{assigns: %{breadcrumbs_tree: current_breadcrumbs_tree}} = socket
      ) do
    {current_level, current_position, text} = List.last(current_breadcrumbs_tree)

    updated_breadcrumbs_tree =
      List.replace_at(
        current_breadcrumbs_tree,
        length(current_breadcrumbs_tree) - 1,
        {current_level, current_position - 1, text}
      )

    socket =
      socket
      |> update(:current_position, &(&1 - 1))
      |> assign(:breadcrumbs_tree, updated_breadcrumbs_tree)

    {:noreply, socket}
  end

  def handle_event("go_down", %{"resource_type" => "page"}, socket), do: {:noreply, socket}

  def handle_event("go_down", %{"selected_resource_index" => selected_resource_index}, socket) do
    current_node =
      get_current_node(socket.assigns.current_level_nodes, socket.assigns.current_position)

    selected_resource_index = String.to_integer(selected_resource_index)

    breadcrumbs_tree =
      socket.assigns.breadcrumbs_tree ++
        [
          {socket.assigns.current_level + 1, selected_resource_index,
           get_resource_prefix(
             current_node,
             socket.assigns.section.display_curriculum_item_numbering,
             socket.assigns.section.customizations
           )}
        ]

    socket =
      socket
      |> update(:current_level, &(&1 + 1))
      |> assign(:current_position, selected_resource_index)
      |> assign(:current_level_nodes, current_node["children"])
      |> assign(:breadcrumbs_tree, breadcrumbs_tree)

    {:noreply, socket}
  end

  def handle_event(
        "breadcrumb-navigate",
        %{"target_level" => target_level, "target_position" => target_position},
        socket
      ) do
    breadcrumbs_tree =
      update_breadcrumbs_tree(
        socket.assigns.breadcrumbs_tree,
        String.to_integer(target_level),
        String.to_integer(target_position)
      )

    current_level_nodes = get_current_level_nodes(breadcrumbs_tree, socket.assigns.hierarchy)

    {level, current_position, _text} = List.last(breadcrumbs_tree)

    socket =
      socket
      |> assign(:breadcrumbs_tree, breadcrumbs_tree)
      |> assign(:current_level, level + 1)
      |> assign(:current_position, current_position)
      |> assign(:current_level_nodes, current_level_nodes)

    {:noreply, socket}
  end

  def handle_event(
        "open_resource",
        %{
          "resource_slug" => resource_slug,
          "resource_type" => resource_type,
          "preview" => "true"
        },
        socket
      ) do
    {:noreply,
     redirect(socket,
       to:
         get_page_preview_delivery_path(
           socket,
           socket.assigns.section.slug,
           resource_slug,
           resource_type
         )
     )}
  end

  def handle_event(
        "open_resource",
        %{"resource_slug" => resource_slug, "resource_type" => resource_type},
        socket
      ) do
    {:noreply,
     redirect(socket,
       to:
         Routes.page_delivery_path(
           socket,
           String.to_existing_atom(resource_type),
           socket.assigns.section.slug,
           resource_slug
         )
     )}
  end

  defp get_page_preview_delivery_path(socket, section_slug, resource_slug, resource_type) do
    Routes.page_delivery_path(
      socket,
      preview_resource_type(resource_type),
      section_slug,
      resource_slug
    )
  end

  defp preview_resource_type(resource_type) do
    case resource_type do
      "page" -> :page_preview
      "container" -> :container_preview
    end
  end

  defp update_breadcrumbs_tree(breadcrumbs_tree, 0, _target_position),
    do: [hd(breadcrumbs_tree)]

  defp update_breadcrumbs_tree(breadcrumbs_tree, target_level, target_position) do
    {true, breadcrumbs_tree} =
      Enum.reduce(breadcrumbs_tree, {false, []}, fn b, acc ->
        {level, position, _text} = b
        {found, breadcrumbs_tree} = acc

        if level == target_level and position == target_position and found == false do
          {true, breadcrumbs_tree}
        else
          if found == true do
            {true, breadcrumbs_tree}
          else
            {false, [b | breadcrumbs_tree]}
          end
        end
      end)

    Enum.reverse(breadcrumbs_tree)
  end

  defp get_current_level_nodes(breadcrumbs_tree, hierarchy) do
    {0, current_level_nodes} =
      breadcrumbs_tree
      |> Enum.reduce({length(breadcrumbs_tree) - 1, hierarchy["children"]}, fn b, acc ->
        {steps_remaining, hierarchy} = acc
        {_level, position, _text} = b

        if steps_remaining == 0 do
          {0, hierarchy}
        else
          {steps_remaining - 1, Enum.fetch!(hierarchy, position)["children"]}
        end
      end)

    current_level_nodes
  end

  defp get_current_node(current_level_nodes, current_position),
    do: Enum.fetch!(current_level_nodes, current_position)

  defp get_current_node_progress(
         current_level_nodes,
         current_position,
         current_user_id,
         section_id
       ) do
    case get_current_node(current_level_nodes, current_position) do
      %{"type" => "container", "id" => container_id} ->
        Metrics.progress_for(section_id, current_user_id, container_id) * 100

      %{"type" => "page", "id" => page_id} ->
        Metrics.progress_for_page(section_id, current_user_id, page_id) * 100

      _ ->
        0.0
    end
  end

  defp get_resource_name(
         current_level_nodes,
         current_position,
         display_curriculum_item_numbering,
         customizations
       ) do
    current_node = get_current_node(current_level_nodes, current_position)

    "#{get_resource_prefix(current_node, display_curriculum_item_numbering, customizations)}: #{current_node["title"]}"
  end

  defp get_resource_prefix(%{"type" => "page"} = page, display_curriculum_item_numbering, _),
    do: if(display_curriculum_item_numbering, do: "Page #{page["index"]}", else: "Page")

  defp get_resource_prefix(
         %{"type" => "container", "level" => "1"} = unit,
         display_curriculum_item_numbering,
         customizations
       ) do
    container_label =
      Numbering.container_type_label(%Numbering{
        level: 1,
        labels: customizations
      })

    if display_curriculum_item_numbering do
      "#{container_label} #{unit["index"]}"
    else
      container_label
    end
  end

  defp get_resource_prefix(
         %{"type" => "container", "level" => "2"} = module,
         display_curriculum_item_numbering,
         customizations
       ) do
    container_label =
      Numbering.container_type_label(%Numbering{
        level: 2,
        labels: customizations
      })

    if display_curriculum_item_numbering do
      "#{container_label} #{module["index"]}"
    else
      container_label
    end
  end

  defp get_resource_prefix(
         %{"type" => "container", "level" => _} = section,
         display_curriculum_item_numbering,
         customizations
       ) do
    container_label =
      Numbering.container_type_label(%Numbering{
        level: nil,
        labels: customizations
      })

    if display_curriculum_item_numbering do
      "#{container_label} #{section["index"]}"
    else
      container_label
    end
  end
end
