defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Shell do
  use OliWeb, :live_component

  alias OliWeb.Components.Delivery.Utils, as: DeliveryUtils
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
    |> then(fn params ->
      Map.update(params, "tile_support", %{}, fn tile_support ->
        # Scope navigation keeps cross-scope viewing intent (search/filter), but
        # resets state that depends on the current dataset shape. Bucket selection
        # and pagination are scope-specific, so dropping them lets Student Support
        # choose the correct default bucket and restart the list at page 1.
        tile_support
        |> normalize_tile_support_params()
        |> Map.drop(["bucket", "page"])
      end)
    end)
  end

  defp dashboard_navigation_params(_), do: %{}

  defp normalize_tile_support_params(tile_support) when is_map(tile_support) do
    Enum.into(tile_support, %{}, fn {key, value} -> {to_string(key), value} end)
  end

  defp normalize_tile_support_params(tile_support) when is_list(tile_support) do
    if Enum.all?(tile_support, &match?({_, _}, &1)) do
      Enum.into(tile_support, %{}, fn {key, value} -> {to_string(key), value} end)
    else
      %{}
    end
  end

  defp normalize_tile_support_params(_), do: %{}

  defp show_prototype_validation_ui? do
    Code.ensure_loaded?(Mix) and function_exported?(Mix, :env, 0) and Mix.env() == :dev
  end

  defp render_dashboard_section(assigns, %{id: "engagement"} = section) do
    section_slug = assigns.section.slug
    section_title = assigns.section.title

    assigns =
      assigns
      |> assign(:section_slug, section_slug)
      |> assign(:section_title, section_title)
      |> assign(:instructor_email, instructor_email(assigns))
      |> assign(:instructor_name, instructor_name(assigns))
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
      section_title={@section_title}
      instructor_email={@instructor_email}
      instructor_name={@instructor_name}
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

  defp instructor_email(assigns) do
    cond do
      Map.get(assigns, :current_author) -> assigns.current_author.email
      Map.get(assigns, :current_user) -> assigns.current_user.email
      true -> nil
    end
  end

  defp instructor_name(assigns) do
    cond do
      Map.get(assigns, :current_author) -> DeliveryUtils.user_name(assigns.current_author)
      Map.get(assigns, :current_user) -> DeliveryUtils.user_name(assigns.current_user)
      true -> nil
    end
  end
end
