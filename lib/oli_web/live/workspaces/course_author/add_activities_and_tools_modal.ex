defmodule OliWeb.Workspaces.CourseAuthor.AddActivitiesAndToolsModal do
  use OliWeb, :live_component

  alias OliWeb.Components.Modal
  alias OliWeb.Components.Common

  def mount(socket) do
    {:ok, assign(socket, loading?: true, tools: [], activities: [])}
  end

  def handle_event("show_modal", %{"project_id" => project_id}, socket) do
    # TODO: Replace with real queries
    tools = fetch_external_tools(project_id)
    activities = fetch_advanced_activities(project_id)
    {:noreply, assign(socket, loading?: false, tools: tools, activities: activities)}
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
      <Modal.modal id={@id<> "-modal"} show={false} class="w-auto min-w-[75%]">
        <:title>Add Advanced Activities & External Tools</:title>
        <div>
          <!-- TODO: Tabs and selection UI go here -->
          <div class="text-center text-gray-500">Tools and activities loaded. (UI coming soon)</div>
        </div>
      </Modal.modal>
    </div>
    """
  end

  # Placeholder
  defp fetch_external_tools(_project_id), do: []
  # Placeholder
  defp fetch_advanced_activities(_project_id), do: []
end
