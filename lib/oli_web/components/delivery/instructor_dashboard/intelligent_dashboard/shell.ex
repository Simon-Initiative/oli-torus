defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Shell do
  use OliWeb, :live_component

  alias OliWeb.Components.Delivery.ListNavigator

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.TileGroups.ContentSection

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.TileGroups.EngagementSection

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.SummaryTile
  alias OliWeb.Delivery.InstructorDashboard.IntelligentDashboardTab

  @impl Phoenix.LiveComponent
  def render(assigns) do
    assigns = assign(assigns, :show_prototype_validation_ui, show_prototype_validation_ui?())

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
            path_builder_fn={
              fn item ->
                dashboard_path(@section.slug, item.resource_id, dashboard_navigation_params(@params))
              end
            }
          />
        </div>
      </div>

      <div id="learning-dashboard-shell" class="space-y-6">
        <SummaryTile.tile status="Loading summary placeholders" />

        <div id="learning-dashboard-sections" class="space-y-6">
          <%= for section <- @dashboard_visible_sections do %>
            {render_dashboard_section(assigns, section)}
          <% end %>
        </div>
      </div>

      <%= if @show_prototype_validation_ui do %>
        <%!--
          TODO(intelligent-dashboard): Remove this prototype validation UI once the
          epic is fully implemented and production tiles render the final data model.
        --%>
        <div
          id="learning-dashboard-runtime-status"
          class="my-4 p-4 bg-white dark:bg-gray-800 shadow-sm"
        >
          <h3 class="font-semibold mb-2">Lane 1 Runtime Status</h3>
          <pre class="text-xs whitespace-pre-wrap">{@dashboard.runtime_status_text}</pre>
        </div>

        <div
          id="learning-dashboard-progress-tile"
          class="mb-4 p-4 bg-white dark:bg-gray-800 shadow-sm"
        >
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
      <% end %>
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

  defp dashboard_path(section_slug, "course", params),
    do: IntelligentDashboardTab.path_for_section(section_slug, "course", params)

  defp dashboard_path(section_slug, resource_id, params),
    do: IntelligentDashboardTab.path_for_section(section_slug, "container:#{resource_id}", params)

  defp dashboard_navigation_params(params) when is_map(params) do
    Enum.into(params, %{}, fn {key, value} -> {to_string(key), value} end)
    |> Enum.filter(fn {key, _value} -> String.starts_with?(key, "tile_") end)
    |> Map.new()
  end

  defp dashboard_navigation_params(_), do: %{}

  defp show_prototype_validation_ui? do
    Code.ensure_loaded?(Mix) and function_exported?(Mix, :env, 0) and Mix.env() == :dev
  end

  defp render_dashboard_section(assigns, %{id: "engagement"} = section) do
    section_slug = assigns.section.slug

    assigns =
      assigns
      |> assign(:section_slug, section_slug)
      |> assign(:section, section)
      |> assign(:show_move_handle, length(assigns.dashboard_visible_sections) > 1)

    ~H"""
    <EngagementSection.section
      expanded={@section.expanded}
      show_move_handle={@show_move_handle}
      progress_status={Map.get(@dashboard, :progress_text, "Loading...")}
      student_support_projection={Map.get(@dashboard, :student_support_projection, %{})}
      student_support_tile_state={@student_support_tile_state}
      params={@params}
      section_slug={@section_slug}
      dashboard_scope={@dashboard_scope}
      show_progress_tile={section_has_tile?(@section, "progress")}
      show_student_support_tile={section_has_tile?(@section, "student_support")}
    />
    """
  end

  defp render_dashboard_section(assigns, %{id: "content"} = section) do
    section_slug = assigns.section.slug

    assigns =
      assigns
      |> assign(:section_slug, section_slug)
      |> assign(:section, section)
      |> assign(:show_move_handle, length(assigns.dashboard_visible_sections) > 1)

    ~H"""
    <ContentSection.section
      expanded={@section.expanded}
      show_move_handle={@show_move_handle}
      objectives_status={tile_status(@dashboard, :objectives_text)}
      assessments_status={tile_status(@dashboard, :assessments_text)}
      show_objectives_tile={section_has_tile?(@section, "objectives")}
      show_assessments_tile={section_has_tile?(@section, "assessments")}
    />
    """
  end

  defp section_has_tile?(section, tile_id) do
    Enum.any?(Map.get(section, :tiles, []), &(Map.get(&1, :id) == tile_id))
  end

  defp tile_status(dashboard, key) do
    Map.get(dashboard, key, "Waiting for scoped data")
  end
end
