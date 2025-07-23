defmodule OliWeb.Workspaces.CourseAuthor.AddActivitiesAndToolsModal do
  use OliWeb, :live_component

  alias OliWeb.Components.Modal
  alias OliWeb.Components.Common
  alias Oli.Activities

  def mount(socket) do
    {:ok,
     assign(socket,
       loading?: true,
       tools: [],
       activities: [],
       active_tab: "activities"
     )}
  end

  def handle_event("show_modal", %{"project_id" => project_id}, socket) do
    selectable_items =
      Activities.selectable_activities_for_project(project_id, socket.assigns.is_admin)

    {activities, tools} =
      Enum.split_with(selectable_items, fn item ->
        # LTI tools have a deployment_id
        is_nil(item.deployment_id)
      end)

    selected_activity_ids =
      Enum.flat_map(selectable_items, fn
        %{project_status: status} = item when status in [:enabled, :disabled] ->
          # enabled or disabled tools are already in the project (they have previously been added/selected)
          [item.id]

        _ ->
          []
      end)
      |> MapSet.new()

    {:noreply,
     assign(socket,
       loading?: false,
       tools: tools,
       activities: activities,
       initial_selected_items: selected_activity_ids,
       current_selected_items: selected_activity_ids,
       project_id: project_id
     )}
  end

  def handle_event("toggle_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab)}
  end

  def handle_event("toggle_selection", %{"activity_id" => activity_id}, socket) do
    selected_items = socket.assigns.current_selected_items
    activity_id = String.to_integer(activity_id)

    new_selected_items =
      if MapSet.member?(selected_items, activity_id) do
        MapSet.delete(selected_items, activity_id)
      else
        MapSet.put(selected_items, activity_id)
      end

    {:noreply, assign(socket, current_selected_items: new_selected_items)}
  end

  def handle_event("save_selections", _params, socket) do
    project_id = socket.assigns.project_id
    selected_items = socket.assigns.current_selected_items
    initial_selected_items = socket.assigns.initial_selected_items

    # Calculate changes
    to_add = MapSet.difference(selected_items, initial_selected_items) |> MapSet.to_list()
    to_remove = MapSet.difference(initial_selected_items, selected_items) |> MapSet.to_list()

    case Activities.bulk_update_project_activities(project_id, to_add, to_remove) do
      :ok ->
        send(self(), {:flash_message, {:info, "Activities and tools updated successfully."}})
        send(self(), {:refresh_tools_and_activities})
        {:noreply, socket}

      {:error, message} ->
        send(self(), {:flash_message, {:error, message}})
        {:noreply, socket}
    end
  end

  def render(%{loading?: true} = assigns) do
    ~H"""
    <div id={@id}>
      <Modal.modal id={@id <> "-modal"} show={false} class="w-auto min-w-[75%]">
        <:title>Add Advanced Activities & External Tools</:title>
        <div>
          <Common.loading_spinner />
        </div>
      </Modal.modal>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div id={@id}>
      <Modal.modal
        id={@id <> "-modal"}
        show={true}
        class="!w-[75%] h-[90vh]"
        header_class="flex items-center justify-between p-4 border-b border-[#CED1D9] dark:border-[#3B3740]"
      >
        <:title>Add Advanced Activities & External Tools</:title>
        <div class="w-80 inline-flex justify-start items-center text-sm text-center font-semibold leading-none">
          <button
            phx-click="toggle_tab"
            phx-value-tab="activities"
            phx-target={@myself}
            data-selected={"#{@active_tab == "activities"}"}
            class={[
              "flex-1 px-2 py-3 rounded-tl-lg rounded-bl-lg flex justify-center items-center gap-1.5",
              "selected:text-white selected:bg-[#0080FF] selected:hover:bg-[#0075EB] selected:dark:bg-[#0062F2] selected:dark:hover:bg-[#0D70FF]",
              "not-selected:text-[#45464C] not-selected:dark:text-[#BAB8BF] not-selected:border-l not-selected:border-t not-selected:border-b not-selected:border-[#CED1D9] not-selected:dark:border-[#3B3740]"
            ]}
          >
            Advanced Activities
          </button>
          <button
            phx-click="toggle_tab"
            phx-value-tab="tools"
            phx-target={@myself}
            data-selected={"#{@active_tab == "tools"}"}
            class={[
              "flex-1 px-2 py-3 rounded-tr-lg rounded-br-lg flex justify-center items-center gap-1.5",
              "selected:text-white selected:bg-[#0080FF] selected:hover:bg-[#0075EB] selected:dark:bg-[#0062F2] selected:dark:hover:bg-[#0D70FF]",
              "not-selected:text-[#45464C] not-selected:dark:text-[#BAB8BF] not-selected:border-r not-selected:border-t not-selected:border-b not-selected:border-[#CED1D9] not-selected:dark:border-[#3B3740]"
            ]}
          >
            External Tools
          </button>
        </div>
        <!-- Tab Content -->
        <div class="max-h-96 overflow-y-auto">
          <!-- Advanced Activities Tab -->
          <div :if={@active_tab == "activities"} class="space-y-6">
            <div>
              <div
                :for={item <- @activities}
                class="w-full flex items-center h-10 pl-2 border-b border-[#CED1D9] dark:border-[#3B3740]"
                phx-click="toggle_selection"
                phx-value-activity_id={item.id}
                phx-target={@myself}
              >
                <.input
                  type="checkbox"
                  class="form-check-input"
                  name="tool_#{item.id}"
                  value={item.id}
                  label={item.title}
                  checked={MapSet.member?(@current_selected_items, item.id)}
                />
              </div>
            </div>

            <div :if={Enum.empty?(@activities)} class="text-center py-12">
              <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-2">
                No Advanced Activities
              </h3>
              <p class="text-sm text-gray-500">
                No advanced activities are currently available for this project.
              </p>
            </div>
          </div>
          <!-- External Tools Tab -->
          <div :if={@active_tab == "tools"} class="space-y-6">
            <div class="text-black dark:text-white text-sm font-normal">
              <p class="mb-4">
                When you add an LTI 1.3 external tool, it becomes available for insertion into a page and automatically inherits the page's properties (e.g., scored or practice). The tool will transmit learner roles, names, and grades to the course assessment scores. Instructors can then configure the tool in their course section if needed.
              </p>
              <p>
                <.link href="#" phx-click={JS.dispatch("click", to: "#trigger-tech-support-modal")}>
                  Contact Support
                </.link>
                if you would like to add a new LTI 1.3 tool to this list.
              </p>
            </div>
            <div>
              <div
                :for={item <- @tools}
                class="w-full flex items-center h-10 pl-2 border-b border-[#CED1D9] dark:border-[#3B3740]"
                phx-click="toggle_selection"
                phx-value-activity_id={item.id}
                phx-target={@myself}
              >
                <.input
                  type="checkbox"
                  class="form-check-input"
                  name="tool_#{item.id}"
                  value={item.id}
                  label={item.title}
                  checked={MapSet.member?(@current_selected_items, item.id)}
                />
              </div>
            </div>
            <div :if={Enum.empty?(@tools)} class="text-center py-12">
              <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-2">
                No External Tools
              </h3>
              <p class="text-sm text-gray-500">
                No external tools have been configured at the system level.
              </p>
            </div>
          </div>
        </div>
        <!-- Action Buttons -->
        <div class="flex justify-end space-x-3 mt-8 text-sm font-normal leading-none">
          <button
            class="px-4 py-2 rounded-md outline outline-1 outline-offset-[-1px] outline-blue-500 hover:opacity-90 text-[#0165DA] dark:text-[#4CA6FF]"
            phx-click={Modal.hide_modal(@id <> "-modal")}
          >
            Cancel
          </button>
          <button
            class="px-4 py-2 rounded-md hover:opacity-90 text-white bg-[#0165DA] dark:bg-[#4CA6FF]"
            phx-click={JS.push("save_selections") |> Modal.hide_modal(@id <> "-modal")}
            phx-target={@myself}
          >
            <%= if @active_tab == "activities", do: "Add Activities", else: "Add Tools" %>
          </button>
        </div>
      </Modal.modal>
    </div>
    """
  end
end
