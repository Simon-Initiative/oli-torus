defmodule OliWeb.Components.Delivery.InstructorDashboard.LearningDashboard do
  use OliWeb, :live_component

  alias Oli.Delivery.Sections
  alias Phoenix.HTML.Form

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="learning-dashboard" class="container mx-auto mb-10">
      <div class="mb-4 p-4 bg-white dark:bg-gray-800 shadow-sm">
        <div class="flex flex-col md:flex-row md:items-end md:justify-between gap-3">
          <form phx-change="dashboard_scope_changed" phx-target={@myself}>
            <label for="dashboard_scope" class="block text-sm font-semibold mb-1">
              Scope
            </label>
            <select
              id="dashboard_scope"
              name="scope"
              class="form-select"
            >
              {Form.options_for_select(
                [{"Course (all content)", "course"}] ++
                  dashboard_scope_options(@containers, @section.customizations),
                @dashboard_scope
              )}
            </select>
          </form>

          <button class="btn btn-secondary" phx-click="dashboard_reload" phx-target={@myself}>
            Reload Snapshot
          </button>
        </div>
      </div>

      <div id="learning-dashboard-runtime-status" class="mb-4 p-4 bg-white dark:bg-gray-800 shadow-sm">
        <h3 class="font-semibold mb-2">Lane 1 Runtime Status</h3>
        <pre class="text-xs whitespace-pre-wrap">{@dashboard.runtime_status_text}</pre>
      </div>

      <div id="learning-dashboard-progress-tile" class="mb-4 p-4 bg-white dark:bg-gray-800 shadow-sm">
        <h3 class="font-semibold mb-2">Progress</h3>
        <pre class="text-xs whitespace-pre-wrap">{@dashboard.progress_text}</pre>
      </div>

      <div
        id="learning-dashboard-student-support-tile"
        class="p-4 bg-white dark:bg-gray-800 shadow-sm"
      >
        <h3 class="font-semibold mb-2">Progress / Proficiency</h3>
        <pre class="text-xs whitespace-pre-wrap">{@dashboard.student_support_text}</pre>
      </div>
    </div>
    """
  end

  @impl Phoenix.LiveComponent
  def handle_event("dashboard_scope_changed", %{"scope" => scope}, socket) do
    send(self(), {:dashboard_scope_changed, scope})
    {:noreply, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("dashboard_reload", _params, socket) do
    # Prototype-only refresh control. The production dashboard flow is expected to
    # rely on scope-driven hydration via `Oli.Dashboard.LiveDataCoordinator`
    # instead of a manual reload action.
    send(self(), :dashboard_reload)
    {:noreply, socket}
  end

  defp dashboard_scope_options({_, containers}, customizations) do
    Enum.map(containers, fn container ->
      {dashboard_container_option_label(container, customizations), "container:#{container.id}"}
    end)
  end

  defp dashboard_scope_options(_, _), do: []

  defp dashboard_container_option_label(container, customizations) do
    title = Map.get(container, :title, "Container")

    case Map.get(container, :label) do
      label when is_binary(label) and label != "" ->
        "#{label} - #{title}"

      _ ->
        case {Map.get(container, :numbering_level), Map.get(container, :numbering_index)} do
          {numbering_level, numbering_index}
          when is_integer(numbering_level) and is_integer(numbering_index) ->
            label =
              Sections.get_container_label_and_numbering(
                numbering_level,
                numbering_index,
                customizations
              )

            "#{label}: #{title}"

          _ ->
            title
        end
    end
  end
end
