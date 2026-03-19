defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.ProgressTile do
  @moduledoc """
  Progress tile for Intelligent Dashboard (`MER-5251`).
  """

  use OliWeb, :live_component

  alias Oli.InstructorDashboard.DataSnapshot.Projections.Progress.Projector
  alias OliWeb.Delivery.InstructorDashboard.IntelligentDashboardTab

  @threshold_options Enum.to_list(10..100//10)

  @impl Phoenix.LiveComponent
  def render(assigns) do
    projected =
      projected_view_model(Map.get(assigns, :projection, %{}), Map.get(assigns, :tile_state, %{}))

    assigns =
      assigns
      |> assign(:projected, projected)
      |> assign(:threshold_options, @threshold_options)

    ~H"""
    <article
      id="learning-dashboard-progress-tile"
      class="h-full rounded-xl border border-Border-border-subtle bg-Surface-surface-primary p-4 shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)]"
    >
      <div class="mb-4 flex items-start justify-between gap-4">
        <div>
          <h3 class="text-lg font-semibold leading-6 text-Text-text-high">Progress</h3>
          <p class="mt-1 max-w-[32rem] text-sm leading-5 text-Text-text-low">
            {description_text(@projected)}
          </p>
        </div>
        <.link
          patch={view_details_path(assigns)}
          class="text-sm font-semibold text-Text-text-button underline-offset-2 hover:underline"
        >
          View Progress Details
        </.link>
      </div>

      <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
        <p class="text-sm font-semibold text-Text-text-high">
          Class size: <span data-role="progress-class-size">{@projected.class_size}</span>
        </p>

        <div class="flex flex-wrap items-center gap-2">
          <details class="relative">
            <summary class="cursor-pointer list-none rounded-md border border-Border-border-default bg-Background-bg-primary px-3 py-2 text-sm font-semibold text-Text-text-high">
              Completion Threshold: {@projected.completion_threshold}%
            </summary>
            <div class="absolute right-0 z-10 mt-2 grid min-w-[10rem] gap-1 rounded-lg border border-Border-border-subtle bg-Surface-surface-primary p-2 shadow-lg">
              <%= for threshold <- @threshold_options do %>
                <.link
                  patch={tile_patch_path(assigns, %{"threshold" => threshold, "page" => 1})}
                  data-threshold={threshold}
                  class={[
                    "rounded-md px-2 py-1 text-sm",
                    threshold == @projected.completion_threshold &&
                      "bg-Surface-surface-secondary font-semibold text-Text-text-high",
                    threshold != @projected.completion_threshold && "text-Text-text-low"
                  ]}
                >
                  {threshold}%
                </.link>
              <% end %>
            </div>
          </details>

          <div class="flex items-center rounded-md border border-Border-border-default bg-Background-bg-primary p-1">
            <.mode_button
              current={@projected.y_axis_mode}
              value={:count}
              patch_path={tile_patch_path(assigns, %{"mode" => "count"})}
            />
            <.mode_button
              current={@projected.y_axis_mode}
              value={:percent}
              patch_path={tile_patch_path(assigns, %{"mode" => "percent"})}
            />
          </div>
        </div>
      </div>

      <%= case @projected.empty_state do %>
        <% %{type: :no_scope_children} -> %>
          <div class="rounded-lg border border-Border-border-subtle bg-Background-bg-primary p-5 text-sm leading-6 text-Text-text-low">
            No scoped content is available for this selection yet.
          </div>
        <% %{type: :no_students} -> %>
          <div class="rounded-lg border border-Border-border-subtle bg-Background-bg-primary p-5 text-sm leading-6 text-Text-text-low">
            No students are included in this view yet, so the chart is not rendered.
          </div>
        <% _ -> %>
          <div class="space-y-3">
            <div
              id={"progress-chart-#{@id}"}
              data-role="progress-chart-target"
              class="rounded-lg border border-Border-border-subtle bg-Background-bg-primary p-4"
            >
              <div class="mb-3 flex items-center justify-between gap-3">
                <div>
                  <p class="text-sm font-semibold text-Text-text-high">{@projected.axis_label}</p>
                  <p class="text-xs text-Text-text-low">
                    Showing page {display_page(@projected.page_window.page)} of {display_page(
                      @projected.page_window.total_pages
                    )}
                  </p>
                </div>

                <%= if @projected.page_window.total_pages > 1 do %>
                  <div class="flex items-center gap-2">
                    <.pagination_button
                      enabled={@projected.page_window.page > 1}
                      patch_path={
                        tile_patch_path(assigns, %{"page" => @projected.page_window.page - 1})
                      }
                      label="Previous"
                    />
                    <.pagination_button
                      enabled={@projected.page_window.page < @projected.page_window.total_pages}
                      patch_path={
                        tile_patch_path(assigns, %{"page" => @projected.page_window.page + 1})
                      }
                      label="Next"
                    />
                  </div>
                <% end %>
              </div>

              <div class="grid min-h-[220px] grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
                <%= for item <- @projected.series do %>
                  <div class="rounded-lg border border-Border-border-subtle bg-Surface-surface-primary p-3">
                    <div class="mb-2 flex items-end gap-3">
                      <div
                        class="w-10 rounded-t-sm bg-Fill-Accent-fill-accent-grey-muted"
                        style={"height: #{bar_height(item.value, @projected.y_axis_mode)}px"}
                      >
                      </div>
                      <div>
                        <p class="text-sm font-semibold text-Text-text-high">{item.label}</p>
                        <p class="text-xs text-Text-text-low">
                          {item_value_text(item, @projected.y_axis_mode)}
                        </p>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
      <% end %>
    </article>
    """
  end

  attr :current, :atom, required: true
  attr :value, :atom, required: true
  attr :patch_path, :string, required: true

  defp mode_button(assigns) do
    ~H"""
    <.link
      patch={@patch_path}
      data-mode={@value}
      class={[
        "rounded px-3 py-1.5 text-sm font-semibold transition",
        @current == @value &&
          "bg-Surface-surface-secondary text-Text-text-high",
        @current != @value && "text-Text-text-low"
      ]}
    >
      {mode_label(@value)}
    </.link>
    """
  end

  attr :enabled, :boolean, required: true
  attr :patch_path, :string, required: true
  attr :label, :string, required: true

  defp pagination_button(assigns) do
    ~H"""
    <%= if @enabled do %>
      <.link
        patch={@patch_path}
        class="rounded-md border border-Border-border-default px-3 py-1.5 text-xs font-semibold text-Text-text-high"
      >
        {@label}
      </.link>
    <% else %>
      <span class="rounded-md border border-Border-border-subtle px-3 py-1.5 text-xs font-semibold text-Text-text-low-alpha">
        {@label}
      </span>
    <% end %>
    """
  end

  defp projected_view_model(%{series_all: _series} = projection, tile_state) do
    Projector.reproject(projection, tile_state)
  end

  defp projected_view_model(_projection, tile_state) do
    Projector.reproject(
      %{
        axis_label: "Course Content",
        class_size: 0,
        completion_threshold: Map.get(tile_state, :completion_threshold, 100),
        y_axis_mode: Map.get(tile_state, :y_axis_mode, :count),
        series_all: [],
        schedule_context: nil,
        page_window: %{page: 1, per_page: 7, total_items: 0, total_pages: 0}
      },
      tile_state
    )
  end

  defp description_text(%{schedule_marker: %{present?: true}}),
    do: "View content students have completed compared to the schedule."

  defp description_text(_projection), do: "View content students have completed."

  defp tile_patch_path(assigns, updates) do
    params =
      assigns
      |> Map.get(:params, %{})
      |> Enum.into(%{}, fn {key, value} -> {to_string(key), value} end)

    tile_progress =
      params
      |> Map.get("tile_progress", %{})
      |> Enum.into(%{}, fn {key, value} -> {to_string(key), value} end)
      |> Map.merge(Enum.into(updates, %{}, fn {key, value} -> {to_string(key), value} end))
      |> Enum.reject(fn
        {"threshold", 100} -> true
        {"threshold", "100"} -> true
        {"mode", "count"} -> true
        {"page", 1} -> true
        {"page", "1"} -> true
        {_key, nil} -> true
        _ -> false
      end)
      |> Map.new()

    params =
      if map_size(tile_progress) == 0 do
        Map.delete(params, "tile_progress")
      else
        Map.put(params, "tile_progress", tile_progress)
      end

    IntelligentDashboardTab.path_for_section(
      assigns.section_slug,
      assigns.dashboard_scope,
      params
    )
  end

  defp view_details_path(assigns) do
    case assigns.dashboard_scope do
      "container:" <> id ->
        "/sections/#{assigns.section_slug}/instructor_dashboard/insights/content?#{Plug.Conn.Query.encode(%{"container_id" => id})}"

      _ ->
        "/sections/#{assigns.section_slug}/instructor_dashboard/insights/content"
    end
  end

  defp mode_label(:count), do: "Count"
  defp mode_label(:percent), do: "%"

  defp item_value_text(item, :percent), do: "#{item.percent}% of class"
  defp item_value_text(item, _mode), do: "#{item.count} students"

  defp bar_height(value, :percent), do: max(round(value * 1.6), 4)
  defp bar_height(value, _mode), do: max(value * 12, 4)

  defp display_page(0), do: 1
  defp display_page(value), do: value
end
