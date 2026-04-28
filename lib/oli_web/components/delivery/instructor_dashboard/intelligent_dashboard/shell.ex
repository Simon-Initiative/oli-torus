defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Shell do
  @moduledoc """
  Renders the top-level shell for the Intelligent Dashboard experience.

  The shell owns scope navigation and composes the summary tile plus the visible
  dashboard sections for the active course or container scope.
  """

  use OliWeb, :live_component

  alias OliWeb.Components.Delivery.Utils, as: DeliveryUtils
  alias OliWeb.Components.Delivery.ListNavigator

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.TileGroups.ContentSection

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.TileGroups.EngagementSection

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.SummaryTile
  alias OliWeb.Delivery.InstructorDashboard.IntelligentDashboardTab

  @impl Phoenix.LiveComponent
  def render(assigns) do
    assigns =
      assigns
      |> assign(:show_prototype_validation_ui, show_prototype_validation_ui?())
      |> assign_new(:browser_timezone, fn -> nil end)

    ~H"""
    <div id="learning-dashboard" class="container mx-auto mb-10" phx-hook="Scroller">
      <div class="-mt-9 mb-4 space-y-1.5">
        <div class="flex justify-end">
          <form
            id="intelligent-dashboard-download-form"
            phx-hook="BrowserTimezoneForm"
            action={
              ~p"/sections/#{@section.slug}/instructor_dashboard/downloads/intelligent_dashboard"
            }
            method="get"
          >
            <%= for {name, value} <- download_form_inputs(@params, @dashboard_scope, @browser_timezone) do %>
              <input type="hidden" name={name} value={value} />
            <% end %>
            <button
              type="submit"
              class="inline-flex items-center gap-1.5 text-xs font-bold text-Text-text-button transition hover:text-Text-text-button hover:underline focus:outline-none focus:underline"
              phx-disable-with="Preparing ZIP..."
            >
              <span class="inline-flex items-center justify-center text-current [&_svg]:h-4 [&_svg]:w-4">
                <OliWeb.Icons.download stroke_class="stroke-current" />
              </span>
              <span>Download dashboard data (CSV)</span>
            </button>
          </form>
        </div>

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
        <.live_component
          id="learning_dashboard_summary_tile"
          module={SummaryTile}
          projection={Map.get(@dashboard, :summary_projection, %{})}
          projection_status={Map.get(@dashboard, :summary_projection_status, %{status: :loading})}
          tile_state={Map.get(assigns, :summary_tile_state, %{})}
          show_recommendation={Map.get(@section, :instructor_recommendations_enabled, true)}
        />

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
          id="learning-dashboard-progress-tile-debug"
          class="mb-4 p-4 bg-white dark:bg-gray-800 shadow-sm"
        >
          <h3 class="font-semibold mb-2">Progress</h3>
          <pre class="text-xs whitespace-pre-wrap">{@dashboard.progress_text}</pre>
        </div>

        <div
          id="learning-dashboard-student-support-tile-debug"
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
      |> Map.delete("tile_assessments")
    end)
    |> then(fn params ->
      Map.update(params, "tile_progress", %{}, fn tile_progress ->
        # Progress tile state keeps threshold/mode across scopes, but pagination is
        # scope-local and should reset whenever the scoped dataset changes.
        tile_progress
        |> normalize_tile_progress_params()
        |> Map.drop(["page"])
      end)
    end)
  end

  defp dashboard_navigation_params(_), do: %{}

  defp normalize_tile_support_params(tile_support) when is_map(tile_support) do
    Enum.into(tile_support, %{}, fn {key, value} -> {to_string(key), value} end)
  end

  defp normalize_tile_support_params(tile_support) when is_list(tile_support) do
    case Enum.reduce_while(tile_support, %{}, fn
           {key, value}, acc -> {:cont, Map.put(acc, to_string(key), value)}
           _, _acc -> {:halt, :invalid}
         end) do
      :invalid -> %{}
      normalized -> normalized
    end
  end

  defp normalize_tile_support_params(_), do: %{}

  defp normalize_tile_progress_params(tile_progress) when is_map(tile_progress) do
    Enum.into(tile_progress, %{}, fn {key, value} -> {to_string(key), value} end)
  end

  defp normalize_tile_progress_params(tile_progress) when is_list(tile_progress) do
    case Enum.reduce_while(tile_progress, %{}, fn
           {key, value}, acc -> {:cont, Map.put(acc, to_string(key), value)}
           _, _acc -> {:halt, :invalid}
         end) do
      :invalid -> %{}
      normalized -> normalized
    end
  end

  defp normalize_tile_progress_params(_), do: %{}

  defp show_prototype_validation_ui? do
    Code.ensure_loaded?(Mix) and function_exported?(Mix, :env, 0) and Mix.env() == :dev
  end

  defp download_form_inputs(params, dashboard_scope, browser_timezone) do
    params
    |> normalize_download_params()
    |> Map.put_new("dashboard_scope", dashboard_scope || "course")
    |> maybe_put_timezone(browser_timezone)
    |> flatten_download_params()
  end

  defp normalize_download_params(params) when is_map(params) do
    Enum.into(params, %{}, fn {key, value} -> {to_string(key), value} end)
  end

  defp normalize_download_params(_), do: %{}

  # Seed the form with any known timezone; the client-side form hook overwrites
  # this with the browser's current timezone before submit.
  defp maybe_put_timezone(params, timezone) when is_binary(timezone) and timezone != "" do
    Map.put_new(params, "timezone", timezone)
  end

  defp maybe_put_timezone(params, _timezone), do: params

  defp flatten_download_params(params) when is_map(params) do
    params
    |> Enum.sort_by(fn {key, _value} -> key end)
    |> Enum.flat_map(fn {key, value} -> flatten_download_param(key, value) end)
  end

  defp flatten_download_param(_key, nil), do: []

  defp flatten_download_param(key, value) when is_map(value) do
    value
    |> Enum.sort_by(fn {child_key, _child_value} -> to_string(child_key) end)
    |> Enum.flat_map(fn {child_key, child_value} ->
      flatten_download_param("#{key}[#{child_key}]", child_value)
    end)
  end

  defp flatten_download_param(key, value), do: [{key, to_string(value)}]

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
      progress_projection={Map.get(@dashboard, :progress_projection, %{})}
      progress_tile_state={@progress_tile_state}
      student_support_projection={Map.get(@dashboard, :student_support_projection, %{})}
      student_support_tile_state={@student_support_tile_state}
      show_student_support_parameters_modal={
        Map.get(assigns, :show_student_support_parameters_modal, false)
      }
      student_support_parameters_draft={Map.get(assigns, :student_support_parameters_draft)}
      student_support_parameters_error={Map.get(assigns, :student_support_parameters_error)}
      student_support_parameters_changeset={Map.get(assigns, :student_support_parameters_changeset)}
      params={@params}
      section_slug={@section_slug}
      section_title={@section_title}
      instructor_email={@instructor_email}
      instructor_name={@instructor_name}
      dashboard_scope={@dashboard_scope}
      show_progress_tile={section_has_tile?(@section, "progress")}
      show_student_support_tile={section_has_tile?(@section, "student_support")}
      tile_split={Map.get(@section, :tile_split, 43)}
    />
    """
  end

  defp render_dashboard_section(assigns, %{id: "content"} = section) do
    section_slug = assigns.section.slug
    course_section_id = assigns.section.id
    section_title = assigns.section.title

    assigns =
      assigns
      |> assign(:section_slug, section_slug)
      |> assign(:course_section_id, course_section_id)
      |> assign(:section_title, section_title)
      |> assign(:instructor_email, instructor_email(assigns))
      |> assign(:instructor_name, instructor_name(assigns))
      |> assign(:section, section)
      # Preserve the delivery section slug before `:section` is rebound to the dashboard section config.
      |> assign(:section_slug, section_slug)
      |> assign(:show_move_handle, length(assigns.dashboard_visible_sections) > 1)

    ~H"""
    <ContentSection.section
      expanded={@section.expanded}
      show_move_handle={@show_move_handle}
      objectives_projection={Map.get(@dashboard, :objectives_projection)}
      objectives_projection_status={
        Map.get(@dashboard, :objectives_projection_status, %{status: :loading})
      }
      objectives_projection_identity={Map.get(@dashboard, :objectives_projection_identity, "loading")}
      section_slug={@section_slug}
      assessments_status={tile_status(@dashboard, :assessments_text)}
      assessments_projection={Map.get(@dashboard, :assessments_projection, %{})}
      assessments_tile_state={Map.get(assigns, :assessments_tile_state, %{})}
      ctx={Map.get(assigns, :ctx)}
      section_id={@course_section_id}
      section_title={@section_title}
      instructor_email={@instructor_email}
      instructor_name={@instructor_name}
      show_objectives_tile={section_has_tile?(@section, "objectives")}
      show_assessments_tile={section_has_tile?(@section, "assessments")}
      tile_split={Map.get(@section, :tile_split, 43)}
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
