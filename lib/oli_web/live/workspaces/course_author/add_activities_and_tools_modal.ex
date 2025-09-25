defmodule OliWeb.Workspaces.CourseAuthor.AddActivitiesAndToolsModal do
  use OliWeb, :live_component

  alias Oli.Activities
  alias OliWeb.Components.Common
  alias OliWeb.Components.Delivery.Utils
  alias OliWeb.Components.Modal

  def mount(socket) do
    socket =
      socket
      |> assign(
        loading?: true,
        tools: [],
        activities: [],
        test_env?: test_env?()
      )
      |> reset_modal()

    {:ok, socket}
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
       all_tools: tools,
       all_activities: activities,
       tools: tools,
       activities: activities,
       initial_selected_item_ids: selected_activity_ids,
       current_selected_item_ids: selected_activity_ids,
       project_id: project_id
     )
     |> reset_modal()}
  end

  def handle_event("clear_search", _, socket) do
    %{all_tools: all_tools, all_activities: all_activities} = socket.assigns

    {:noreply, assign(socket, search_term: "", tools: all_tools, activities: all_activities)}
  end

  def handle_event("search", %{"search_term" => search_term}, socket) do
    %{all_tools: all_tools, all_activities: all_activities, active_tab: active_tab} =
      socket.assigns

    {filtered_tools, filtered_activities} =
      apply_search(all_tools, all_activities, active_tab, search_term)

    {:noreply,
     assign(socket,
       search_term: search_term,
       tools: filtered_tools,
       activities: filtered_activities
     )}
  end

  def handle_event("reset_modal", _, socket) do
    {:noreply, reset_modal(socket)}
  end

  def handle_event("toggle_tab", %{"tab" => tab}, socket) do
    %{all_tools: all_tools, all_activities: all_activities} =
      socket.assigns

    {:noreply,
     assign(socket,
       active_tab: tab,
       search_term: "",
       tools: all_tools,
       activities: all_activities
     )}
  end

  def handle_event("toggle_selection", %{"activity_id" => activity_id}, socket) do
    %{
      all_activities: all_activities,
      all_tools: all_tools,
      initial_selected_item_ids: initial_selected_item_ids,
      current_selected_item_ids: current_selected_item_ids
    } = socket.assigns

    activity_id = String.to_integer(activity_id)

    new_selected_item_ids =
      if MapSet.member?(current_selected_item_ids, activity_id) do
        MapSet.delete(current_selected_item_ids, activity_id)
      else
        MapSet.put(current_selected_item_ids, activity_id)
      end

    pending_changes =
      calculate_pending_changes(
        new_selected_item_ids,
        initial_selected_item_ids,
        all_activities,
        all_tools
      )

    {:noreply,
     assign(socket,
       current_selected_item_ids: new_selected_item_ids,
       pending_changes: pending_changes
     )}
  end

  def handle_event("save_selections", _params, socket) do
    %{pending_changes: pending_changes, project_id: project_id} = socket.assigns

    to_add = pending_changes.activities_to_add ++ pending_changes.tools_to_add
    to_remove = pending_changes.activities_to_remove ++ pending_changes.tools_to_remove

    case Activities.bulk_update_project_activities(project_id, to_add, to_remove) do
      :ok ->
        send(self(), {:flash_message, {:info, "Activities and tools updated successfully."}})
        send(self(), {:refresh_tools_and_activities})
        {:noreply, reset_modal(socket)}

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
      <button
        :if={@test_env?}
        id="test-show-modal-button"
        type="button"
        class="hidden"
        phx-click="show_modal"
        phx-target={@myself}
        phx-value-project_id={@project_id}
      >
        Test Show Modal
      </button>
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
        on_cancel={JS.push("reset_modal", target: @myself)}
        header_class="flex items-center justify-between p-4 border-b border-[#CED1D9] dark:border-[#3B3740]"
      >
        <:title>Add Advanced Activities & External Tools</:title>
        <div class="w-80 inline-flex justify-start items-center text-sm text-center font-semibold leading-none">
          <button
            phx-click="toggle_tab"
            phx-value-tab="activities"
            phx-target={@myself}
            data-selected={"#{@active_tab == "activities"}"}
            role="tab"
            data-tab="activities"
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
            role="tab"
            data-tab="tools"
            class={[
              "flex-1 px-2 py-3 rounded-tr-lg rounded-br-lg flex justify-center items-center gap-1.5",
              "selected:text-white selected:bg-[#0080FF] selected:hover:bg-[#0075EB] selected:dark:bg-[#0062F2] selected:dark:hover:bg-[#0D70FF]",
              "not-selected:text-[#45464C] not-selected:dark:text-[#BAB8BF] not-selected:border-r not-selected:border-t not-selected:border-b not-selected:border-[#CED1D9] not-selected:dark:border-[#3B3740]"
            ]}
          >
            External Tools
          </button>
        </div>

        <div :if={@active_tab == "tools"} class="text-black dark:text-white text-sm font-normal">
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

        <div role="search">
          <Utils.search_box
            class="w-56 h-9"
            search_term={@search_term}
            on_search={JS.push("search", target: @myself)}
            on_change={JS.push("search", target: @myself)}
            on_clear_search={JS.push("clear_search", target: @myself)}
          />
        </div>
        <!-- Tab Content -->
        <div class="max-h-96 overflow-y-auto">
          <!-- Advanced Activities Tab -->
          <div :if={@active_tab == "activities"} class="space-y-6">
            <div>
              <div
                :for={item <- @activities}
                class={[
                  "w-full flex items-center h-10 pl-2 border-b border-[#CED1D9] dark:border-[#3B3740]",
                  "hover:bg-gray-50 dark:hover:bg-gray-800 cursor-pointer"
                ]}
                phx-click="toggle_selection"
                phx-value-activity_id={item.id}
                phx-target={@myself}
                role="activity-item"
                data-activity-id={item.id}
              >
                <div class="flex items-center gap-2 flex-1">
                  <.input
                    type="checkbox"
                    class="form-check-input"
                    name="tool_#{item.id}"
                    value={item.id}
                    label=""
                    checked={MapSet.member?(@current_selected_item_ids, item.id)}
                  />
                  <span class="text-sm text-gray-900 dark:text-white">{item.title}</span>
                  <.status_indicator status={
                    get_item_status(item.id, @initial_selected_item_ids, @current_selected_item_ids)
                  } />
                </div>
              </div>
            </div>
            <!-- Warning messages -->
            <div :if={Enum.empty?(@activities) and @search_term != ""} class="text-center py-12">
              <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-2">
                No Advanced Activities Found
              </h3>
              <p class="text-sm text-gray-500">
                No advanced activities match <span class="font-bold italic"><%= @search_term %></span>.
              </p>
            </div>
            <div :if={Enum.empty?(@activities) and @search_term == ""} class="text-center py-12">
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
            <div>
              <div
                :for={item <- @tools}
                class={[
                  "w-full flex items-center h-10 pl-2 border-b border-[#CED1D9] dark:border-[#3B3740]",
                  "hover:bg-gray-50 dark:hover:bg-gray-800 cursor-pointer"
                ]}
                phx-click="toggle_selection"
                phx-value-activity_id={item.id}
                phx-target={@myself}
                role="tool-item"
                data-tool-id={item.id}
              >
                <div class="flex items-center gap-2 flex-1">
                  <.input
                    type="checkbox"
                    class="form-check-input"
                    name="tool_#{item.id}"
                    value={item.id}
                    label=""
                    checked={MapSet.member?(@current_selected_item_ids, item.id)}
                  />
                  <span class="text-sm text-gray-900 dark:text-white">{item.title}</span>
                  <.status_indicator status={
                    get_item_status(item.id, @initial_selected_item_ids, @current_selected_item_ids)
                  } />
                </div>
              </div>
            </div>
            <!-- Warning messages -->
            <div :if={Enum.empty?(@tools) and @search_term != ""} class="text-center py-12">
              <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-2">
                No External Tools Found
              </h3>
              <p class="text-sm text-gray-500">
                No external tools match <span class="font-bold italic"><%= @search_term %></span>.
              </p>
            </div>
            <div :if={Enum.empty?(@tools) and @search_term == ""} class="text-center py-12">
              <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-2">
                No External Tools
              </h3>
              <p class="text-sm text-gray-500">
                No external tools have been configured at the system level.
              </p>
            </div>
          </div>
        </div>
        <!-- Changes Summary and Action Buttons -->
        <div class="flex justify-between items-center mt-8 h-8">
          <.pending_changes_summary pending_changes={@pending_changes} />

          <div class="flex space-x-3 text-sm font-normal leading-none">
            <button
              class="px-4 py-2 rounded-md outline outline-1 outline-offset-[-1px] outline-blue-500 hover:opacity-90 text-[#0165DA] dark:text-[#4CA6FF]"
              phx-click={Modal.hide_modal(@id <> "-modal") |> JS.push("reset_modal", target: @myself)}
              role="cancel-button"
            >
              Cancel
            </button>
            <button
              class={[
                "px-4 py-2 rounded-md hover:opacity-90 text-white",
                if(@pending_changes.has_changes,
                  do: "bg-[#0165DA] dark:bg-[#4CA6FF]",
                  else: "bg-gray-400 dark:bg-gray-600 cursor-not-allowed"
                )
              ]}
              phx-click={JS.push("save_selections") |> Modal.hide_modal(@id <> "-modal")}
              phx-target={@myself}
              disabled={!@pending_changes.has_changes}
              role="apply-button"
            >
              Apply Changes
            </button>
          </div>
        </div>
      </Modal.modal>
    </div>
    """
  end

  attr :pending_changes, :map, required: true

  def pending_changes_summary(%{pending_changes: %{has_changes: false}} = assigns) do
    ~H"""
    <div></div>
    """
  end

  def pending_changes_summary(assigns) do
    ~H"""
    <div class="flex items-center gap-4 text-sm text-gray-700 dark:text-gray-300">
      <span class="font-medium">Changes:</span>
      <div :if={length(@pending_changes.activities_to_add) > 0} class="flex items-center gap-1">
        <.add />
        <span>
          {change_summary_text(length(@pending_changes.activities_to_add), :activities)}
        </span>
      </div>
      <div :if={length(@pending_changes.activities_to_remove) > 0} class="flex items-center gap-1">
        <.remove />
        <span>
          {change_summary_text(length(@pending_changes.activities_to_remove), :activities)}
        </span>
      </div>
      <div :if={length(@pending_changes.tools_to_add) > 0} class="flex items-center gap-1">
        <.add />
        <span>{change_summary_text(length(@pending_changes.tools_to_add), :tools)}</span>
      </div>
      <div :if={length(@pending_changes.tools_to_remove) > 0} class="flex items-center gap-1">
        <.remove />
        <span>{change_summary_text(length(@pending_changes.tools_to_remove), :tools)}</span>
      </div>
    </div>
    """
  end

  def status_indicator(assigns) do
    ~H"""
    <%= case @status do %>
      <% :to_add -> %>
        <.add />
      <% :to_remove -> %>
        <.remove />
      <% :unchanged -> %>
    <% end %>
    """
  end

  def add(assigns) do
    ~H"""
    <span class="text-green-600 dark:text-green-400 font-black text-xl">+</span>
    """
  end

  def remove(assigns) do
    ~H"""
    <span class="text-red-600 dark:text-red-400 font-black text-xl mb-1">-</span>
    """
  end

  defp apply_search(tools, activities, _active_tab, search_term) when search_term == "",
    do: {tools, activities}

  defp apply_search(tools, activities, "activities", search_term) do
    normalized_search_term = String.downcase(search_term)

    activities =
      Enum.filter(activities, fn activity ->
        String.contains?(String.downcase(activity.title), normalized_search_term)
      end)

    {tools, activities}
  end

  defp apply_search(tools, activities, "tools", search_term) do
    normalized_search_term = String.downcase(search_term)

    tools =
      Enum.filter(tools, fn tool ->
        String.contains?(String.downcase(tool.title), normalized_search_term)
      end)

    {tools, activities}
  end

  defp calculate_pending_changes(
         current_selected_items,
         initial_selected_items,
         all_activities,
         all_tools
       ) do
    to_add = MapSet.difference(current_selected_items, initial_selected_items)
    to_remove = MapSet.difference(initial_selected_items, current_selected_items)

    {activities_to_add, activities_to_remove} =
      Enum.reduce(all_activities, {[], []}, fn activity, {add, remove} ->
        cond do
          MapSet.member?(to_add, activity.id) -> {[activity.id | add], remove}
          MapSet.member?(to_remove, activity.id) -> {add, [activity.id | remove]}
          true -> {add, remove}
        end
      end)

    {tools_to_add, tools_to_remove} =
      Enum.reduce(all_tools, {[], []}, fn tool, {add, remove} ->
        cond do
          MapSet.member?(to_add, tool.id) -> {[tool.id | add], remove}
          MapSet.member?(to_remove, tool.id) -> {add, [tool.id | remove]}
          true -> {add, remove}
        end
      end)

    %{
      activities_to_add: activities_to_add,
      activities_to_remove: activities_to_remove,
      tools_to_add: tools_to_add,
      tools_to_remove: tools_to_remove,
      has_changes: MapSet.size(to_add) > 0 or MapSet.size(to_remove) > 0
    }
  end

  defp change_summary_text(1, :activities), do: "1 activity"
  defp change_summary_text(1, :tools), do: "1 tool"
  defp change_summary_text(count, :activities), do: "#{count} activities"
  defp change_summary_text(count, :tools), do: "#{count} tools"

  defp get_item_status(item_id, initial_selected_item_ids, current_selected_item_ids) do
    initial_selected = MapSet.member?(initial_selected_item_ids, item_id)
    currently_selected = MapSet.member?(current_selected_item_ids, item_id)

    cond do
      not initial_selected and currently_selected -> :to_add
      initial_selected and not currently_selected -> :to_remove
      true -> :unchanged
    end
  end

  defp reset_modal(socket) do
    assign(socket,
      pending_changes: %{
        activities_to_add: [],
        activities_to_remove: [],
        tools_to_add: [],
        tools_to_remove: [],
        has_changes: false
      },
      active_tab: "activities",
      search_term: ""
    )
  end

  defp test_env?, do: Application.get_env(:oli, :env) == :test
end
