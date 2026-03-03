defmodule OliWeb.Components.Delivery.InstructorDashboard.LearningDashboard do
  use OliWeb, :live_component

  alias OliWeb.Components.Delivery.ListNavigator
  alias OliWeb.Delivery.InstructorDashboard.DashboardTab

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="learning-dashboard" class="container mx-auto mb-10">
      <div class="mb-4">
        <div class="flex flex-col items-center gap-3">
          <.live_component
            id="learning_dashboard_scope_navigator"
            module={ListNavigator}
            items={navigator_items(@containers)}
            current_item_resource_id={current_dashboard_item_resource_id(@dashboard_scope)}
            navigation_type={:patch}
            path_builder_fn={fn item -> dashboard_path(@section.slug, item.resource_id) end}
          />
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

  defp current_dashboard_item_resource_id("course"), do: "course"

  defp current_dashboard_item_resource_id("container:" <> id) do
    case Integer.parse(id) do
      {parsed, ""} when parsed > 0 -> parsed
      _ -> "course"
    end
  end

  defp current_dashboard_item_resource_id(_), do: "course"

  defp navigator_items({_count, items}) when is_list(items), do: items
  defp navigator_items(items) when is_list(items), do: items
  defp navigator_items(_), do: []

  defp dashboard_path(section_slug, "course"),
    do: DashboardTab.path_for_section(section_slug, "course")

  defp dashboard_path(section_slug, resource_id),
    do: DashboardTab.path_for_section(section_slug, "container:#{resource_id}")
end
