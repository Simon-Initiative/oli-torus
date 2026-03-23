defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.ProgressTile do
  @moduledoc """
  Progress tile for Intelligent Dashboard (`MER-5251`).
  """

  use OliWeb, :live_component

  alias Oli.InstructorDashboard.DataSnapshot.Projections.Progress.Projector
  alias OliWeb.Icons
  alias OliWeb.Delivery.InstructorDashboard.IntelligentDashboardTab

  @threshold_options Enum.to_list(10..100//10)
  @chart_height 280
  @count_chart_ticks 5

  @impl Phoenix.LiveComponent
  def render(assigns) do
    projected =
      projected_view_model(Map.get(assigns, :projection, %{}), Map.get(assigns, :tile_state, %{}))

    chart = chart_view_model(projected)

    assigns =
      assigns
      |> assign(:projected, projected)
      |> assign(:chart, chart)
      |> assign(:threshold_options, @threshold_options)

    ~H"""
    <article
      id="learning-dashboard-progress-tile"
      class="h-full rounded-xl border border-Border-border-subtle bg-Surface-surface-primary p-4 shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)]"
    >
      <div class="mb-4 flex items-start justify-between gap-4">
        <div class="min-w-0">
          <div class="flex items-center gap-2">
            <span class="inline-flex h-5 w-5 items-center justify-center text-Text-text-high">
              <Icons.progress_arrow />
            </span>
            <h3 class="text-lg font-semibold leading-6 text-Text-text-high">Progress</h3>
          </div>
          <p class="mt-1 max-w-[32rem] text-sm leading-5 text-Text-text-low">
            {description_text(@projected)}
          </p>
        </div>
        <.link
          patch={view_details_path(assigns)}
          class="shrink-0 text-sm font-semibold text-Text-text-button underline-offset-2 hover:underline"
        >
          View Progress Details
        </.link>
      </div>

      <%= case @projected.empty_state do %>
        <% %{type: :no_scope_children} -> %>
          <div class="rounded-lg border border-Border-border-subtle bg-Surface-surface-primary p-5 text-sm leading-6 text-Text-text-low">
            No scoped content is available for this selection yet.
          </div>
        <% %{type: :no_students} -> %>
          <div class="rounded-lg border border-Border-border-subtle bg-Surface-surface-primary p-5 text-sm leading-6 text-Text-text-low">
            No students are included in this view yet, so the chart is not rendered.
          </div>
        <% _ -> %>
          <div class="space-y-4">
            <div class="flex flex-wrap items-center justify-between gap-3">
              <p class="rounded-full px-1 text-sm font-semibold text-Text-text-high">
                Class size: <span data-role="progress-class-size">{@projected.class_size}</span>
              </p>

              <div class="flex flex-wrap items-center gap-3">
                <div class="flex items-center gap-1">
                  <span class="text-sm text-Text-text-high">Completion Threshold</span>
                  <div class="group relative inline-flex items-center justify-center">
                    <button
                      type="button"
                      class="inline-flex items-center justify-center rounded-full text-Text-text-low focus:outline-none focus-visible:ring-2 focus-visible:ring-Text-text-button"
                      aria-label="Completion threshold help"
                    >
                      <Icons.info />
                    </button>
                    <div class="pointer-events-none absolute bottom-[calc(100%+8px)] left-1/2 z-20 hidden w-56 -translate-x-1/2 rounded-sm border border-Border-border-default bg-Surface-surface-background px-3 py-2 text-xs leading-4 text-Text-text-high shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] group-hover:block group-focus-within:block">
                      Adjust the percentage considered complete for each visible content item.
                    </div>
                  </div>
                </div>

                <details class="relative">
                  <summary class="cursor-pointer list-none rounded-md border border-Border-border-default bg-Background-bg-primary px-3 py-2 text-sm font-semibold text-Text-text-high">
                    {@projected.completion_threshold}%
                  </summary>
                  <div class="absolute right-0 z-20 mt-2 grid min-w-[9rem] gap-1 rounded-lg border border-Border-border-subtle bg-Surface-surface-primary p-2 shadow-lg">
                    <%= for threshold <- @threshold_options do %>
                      <.link
                        patch={tile_patch_path(assigns, %{"threshold" => threshold, "page" => 1})}
                        data-threshold={threshold}
                        class={[
                          "rounded-md px-2 py-1 text-sm no-underline hover:no-underline hover:text-current",
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
              </div>
            </div>

            <div
              id={"progress-chart-shell-#{@id}"}
              class="rounded-lg bg-inherit p-4"
            >
              <div class="mb-3 flex items-center justify-end">
                <div class="flex items-center gap-1">
                  <.pagination_button
                    enabled={@projected.page_window.page > 1}
                    patch_path={
                      tile_patch_path(assigns, %{"page" => @projected.page_window.page - 1})
                    }
                    label="Previous page"
                    icon_rotation="rotate-90"
                  />
                  <.pagination_button
                    enabled={@projected.page_window.page < @projected.page_window.total_pages}
                    patch_path={
                      tile_patch_path(assigns, %{"page" => @projected.page_window.page + 1})
                    }
                    label="Next page"
                    icon_rotation="-rotate-90"
                  />
                </div>
              </div>

              <div class="flex gap-4">
                <div class="flex flex-col items-center justify-center pt-10">
                  <div class="flex flex-col items-center gap-0 rounded-[6px] p-1">
                    <.mode_button
                      current={@projected.y_axis_mode}
                      value={:percent}
                      patch_path={tile_patch_path(assigns, %{"mode" => "percent"})}
                    />
                    <.mode_button
                      current={@projected.y_axis_mode}
                      value={:count}
                      patch_path={tile_patch_path(assigns, %{"mode" => "count"})}
                    />
                  </div>
                  <div class="mt-3 flex items-center gap-2 [writing-mode:vertical-rl] [transform:rotate(180deg)]">
                    <span class="inline-flex h-[18px] w-[18px] items-center justify-center rounded-[3px] bg-Background-bg-secondary text-[11px] font-semibold text-Text-text-high">
                      Y
                    </span>
                    <span class="text-xs font-semibold text-Text-text-high">Students</span>
                  </div>
                </div>

                <div class="min-w-0 flex-1">
                  <div class="flex gap-3">
                    <div
                      class="flex shrink-0 flex-col justify-between pt-3 text-xs text-Text-text-high"
                      style={"height: #{@chart.height}px"}
                    >
                      <%= for tick <- @chart.y_ticks do %>
                        <span>{tick_label(tick, @projected.y_axis_mode)}</span>
                      <% end %>
                    </div>

                    <div class="min-w-0 flex-1">
                      <div
                        class="relative overflow-visible"
                        style={"height: #{@chart.height}px"}
                      >
                        <%= if @chart.schedule.visible? do %>
                          <div
                            aria-hidden="true"
                            class="absolute inset-y-[12px] left-0 rounded-[2px] bg-[#33181a]"
                            style={"width: #{@chart.schedule.shade_width_pct}%"}
                          >
                          </div>
                          <div
                            aria-hidden="true"
                            class="absolute inset-y-[12px] border-l border-dashed border-[#eeebf5]"
                            style={"left: #{@chart.schedule.marker_left_pct}%"}
                          >
                          </div>
                          <div
                            class="absolute top-0 z-10 -translate-x-1/2"
                            style={"left: #{@chart.schedule.marker_left_pct}%"}
                          >
                            <div class="group relative">
                              <button
                                type="button"
                                class="rounded-sm bg-Background-bg-primary px-2 py-1 text-xs font-semibold text-Text-text-high focus:outline-none focus-visible:ring-2 focus-visible:ring-Text-text-button"
                                aria-label={@chart.schedule.tooltip}
                              >
                                {@chart.schedule.label}
                              </button>
                              <div class="pointer-events-none absolute bottom-[calc(100%+8px)] left-1/2 hidden w-max max-w-[12rem] -translate-x-1/2 rounded-sm border border-Border-border-default bg-Surface-surface-background px-2 py-1 text-xs text-Text-text-high shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] group-hover:block group-focus-within:block">
                                {@chart.schedule.tooltip}
                              </div>
                            </div>
                          </div>
                        <% end %>

                        <div
                          id={"progress-chart-wrapper-#{@id}"}
                          phx-hook="ProgressTileChart"
                          data-spec={Jason.encode!(@chart.spec)}
                          data-chart-target={"progress-chart-canvas-#{@id}"}
                          class="relative h-full"
                        >
                          <div
                            id={"progress-chart-canvas-#{@id}"}
                            phx-update="ignore"
                            class="h-full"
                          >
                          </div>
                        </div>

                        <div
                          aria-hidden="true"
                          class="pointer-events-none absolute inset-x-0 bottom-0 top-[12px] grid items-end gap-3 px-1"
                          style={@chart.columns_style}
                        >
                          <%= for item <- @chart.series do %>
                            <div class="flex h-full items-end justify-center">
                              <div
                                class="w-8 rounded-t-[4px] bg-[#c7c4cf]"
                                style={"height: #{item.bar_height_pct}%"}
                              >
                              </div>
                            </div>
                          <% end %>
                        </div>

                        <div
                          class="pointer-events-none absolute inset-x-0 bottom-0 top-[12px] grid"
                          style={@chart.columns_style}
                        >
                          <%= for item <- @chart.series do %>
                            <div class="relative h-full">
                              <%= if item.bar_height_pct > 0 do %>
                                <div
                                  class="group pointer-events-auto absolute inset-x-1 bottom-0"
                                  style={"height: #{item.bar_height_pct}%"}
                                >
                                  <button
                                    type="button"
                                    class="h-full w-full cursor-default rounded-md bg-transparent focus:outline-none focus-visible:ring-2 focus-visible:ring-Text-text-button"
                                    aria-label={bar_accessible_label(item, @projected)}
                                  >
                                  </button>
                                  <div class="pointer-events-none absolute bottom-[calc(100%+8px)] left-1/2 hidden -translate-x-1/2 rounded-sm border border-Border-border-default bg-Surface-surface-background px-2 py-1 text-xs font-semibold text-Text-text-high shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] group-hover:block group-focus-within:block">
                                    {item.hover_value_text}
                                  </div>
                                </div>
                              <% end %>
                            </div>
                          <% end %>
                        </div>
                      </div>

                      <div
                        class="mt-4 grid items-start gap-3"
                        style={@chart.columns_style}
                      >
                        <%= for item <- @chart.series do %>
                          <div class="group relative min-w-0 text-center">
                            <button
                              type="button"
                              class="w-full truncate text-xs text-Text-text-high focus:outline-none focus-visible:ring-2 focus-visible:ring-Text-text-button"
                              aria-label={"#{item.label}. #{item.value_text}"}
                            >
                              {item.short_label}
                            </button>
                            <div class="pointer-events-none invisible absolute z-20 rounded-sm border border-Border-border-default bg-Surface-surface-background px-2 py-1 text-xs text-Text-text-high shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] group-hover:visible group-focus-within:visible">
                              {item.label}
                            </div>
                          </div>
                        <% end %>
                      </div>

                      <div class="mt-4 flex items-center gap-2 text-xs text-Text-text-high">
                        <span class="inline-flex h-[18px] w-[18px] items-center justify-center rounded-[3px] bg-Background-bg-secondary font-semibold text-Text-text-high">
                          X
                        </span>
                        <span class="font-semibold">{@projected.axis_label}</span>
                      </div>
                    </div>
                  </div>
                </div>
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
      aria-label={"Show #{@value} on the y-axis"}
      class={[
        "inline-flex h-8 w-8 items-center justify-center rounded-[4px] border text-sm font-semibold leading-4 no-underline transition hover:no-underline hover:text-current",
        @current == @value &&
          "border-Text-text-button bg-Text-text-button text-white",
        @current != @value &&
          "border-Border-border-default bg-Background-bg-secondary text-Text-text-high"
      ]}
    >
      {mode_label(@value)}
    </.link>
    """
  end

  attr :enabled, :boolean, required: true
  attr :patch_path, :string, required: true
  attr :label, :string, required: true
  attr :icon_rotation, :string, default: ""

  defp pagination_button(assigns) do
    ~H"""
    <%= if @enabled do %>
      <.link
        patch={@patch_path}
        aria-label={@label}
        class="inline-flex h-7 w-7 items-center justify-center rounded-[4px] bg-Background-bg-secondary text-Icon-icon-active no-underline transition hover:no-underline focus:no-underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
      >
        <Icons.chevron_right
          width="16"
          height="16"
          class={"fill-Icon-icon-active stroke-Icon-icon-active #{@icon_rotation}"}
        />
      </.link>
    <% else %>
      <span
        aria-hidden="true"
        class="inline-flex h-7 w-7 items-center justify-center rounded-[4px] bg-Background-bg-secondary"
      >
        <Icons.chevron_right
          width="16"
          height="16"
          class={"fill-Fill-Buttons-fill-muted-hover stroke-Fill-Buttons-fill-muted-hover #{@icon_rotation}"}
        />
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

  defp chart_view_model(projected) do
    scale_series = Map.get(projected, :series_all, projected.series)
    y_ticks = y_ticks(scale_series, projected.y_axis_mode, projected.class_size)
    max_value = max(List.first(y_ticks) || 0, 1)
    series = chart_series(projected.series, max_value, projected.y_axis_mode)

    %{
      height: @chart_height,
      y_ticks: y_ticks,
      series: series,
      columns_style: columns_style(series),
      spec: build_chart_spec(series, max_value),
      schedule: schedule_overlay(projected.schedule_marker, series)
    }
  end

  defp chart_series(series, max_value, y_axis_mode) do
    Enum.with_index(series)
    |> Enum.map(fn {item, index} ->
      bar_top_pct = max(Float.round(item.value / max_value * 100.0, 2), 0.0)

      %{
        id: item.container_id,
        label: item.label,
        short_label: truncate_label(item.label),
        value: item.value,
        value_text: item_value_text(item, y_axis_mode),
        hover_value_text: hover_value_text(item.value, y_axis_mode),
        order: index,
        bar_top_pct: bar_top_pct,
        bar_height_pct: visible_bar_height_pct(item.value, bar_top_pct)
      }
    end)
  end

  defp build_chart_spec(series, max_value) do
    values =
      Enum.map(series, fn item ->
        %{
          resource_id: item.id,
          order: item.order,
          value: item.value
        }
      end)

    %{
      "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
      "background" => "transparent",
      "autosize" => %{"type" => "fit-x", "contains" => "padding", "resize" => true},
      "width" => "container",
      "height" => @chart_height,
      "padding" => %{"left" => 0, "right" => 0, "top" => 12, "bottom" => 0},
      "data" => %{"values" => values},
      "view" => %{"stroke" => nil},
      "mark" => %{
        "type" => "bar",
        "cornerRadiusTopLeft" => 4,
        "cornerRadiusTopRight" => 4,
        "color" => "#c7c4cf",
        "size" => 32
      },
      "encoding" => %{
        "x" => %{"field" => "order", "type" => "ordinal", "axis" => nil},
        "y" => %{
          "field" => "value",
          "type" => "quantitative",
          "scale" => %{"domain" => [0, max_value]},
          "axis" => %{
            "title" => nil,
            "domain" => false,
            "ticks" => false,
            "labels" => false,
            "grid" => true,
            "gridColor" => "#3b3740",
            "gridOpacity" => 1
          }
        },
        "tooltip" => [
          %{"field" => "value", "type" => "quantitative", "title" => "Value"}
        ]
      },
      "config" => %{
        "axis" => %{"labelColor" => "#eeebf5"},
        "background" => "transparent"
      }
    }
  end

  defp schedule_overlay(
         %{present?: true, visible?: true, container_id: container_id} = marker,
         series
       ) do
    index = Enum.find_index(series, &(&1.id == container_id)) || 0
    count = max(length(series), 1)
    marker_left_pct = Float.round((index + 0.5) / count * 100.0, 2)

    %{
      visible?: true,
      marker_left_pct: marker_left_pct,
      shade_width_pct: marker_left_pct,
      label: marker.label,
      tooltip: marker.tooltip
    }
  end

  defp schedule_overlay(_marker, _series) do
    %{visible?: false, marker_left_pct: 0.0, shade_width_pct: 0.0, label: nil, tooltip: nil}
  end

  defp y_ticks(_series, :percent, _class_size) do
    [100, 75, 50, 25, 0]
  end

  defp y_ticks(series, _mode, class_size) do
    max_count = series |> Enum.map(& &1.count) |> Enum.max(fn -> 0 end)
    max_value = count_axis_upper_bound(max_count, class_size)
    step_count = max(@count_chart_ticks - 1, 1)

    0..step_count
    |> Enum.map(fn index ->
      max_value - round(index * (max_value / step_count))
    end)
    |> Enum.map(&max(&1, 0))
    |> Enum.uniq()
  end

  defp count_axis_upper_bound(0, class_size) when class_size > 0 do
    nice_axis_ceiling(min(class_size, 4))
  end

  defp count_axis_upper_bound(max_count, class_size) do
    hard_cap =
      class_size
      |> max(max_count)
      |> max(1)

    max_count
    |> nice_axis_ceiling()
    |> min(hard_cap)
    |> max(max_count)
  end

  defp nice_axis_ceiling(value) when value <= 1, do: 1

  defp nice_axis_ceiling(value) do
    exponent =
      value
      |> :math.log10()
      |> Float.floor()
      |> trunc()

    magnitude = :math.pow(10, exponent)
    normalized = value / magnitude

    step =
      cond do
        normalized <= 1 -> 1
        normalized <= 2 -> 2
        normalized <= 5 -> 5
        true -> 10
      end

    trunc(step * magnitude)
  end

  defp columns_style([]), do: "grid-template-columns: repeat(1, minmax(0, 1fr));"

  defp columns_style(series) do
    "grid-template-columns: repeat(#{length(series)}, minmax(0, 1fr));"
  end

  defp visible_bar_height_pct(0, _bar_top_pct), do: 0.0
  defp visible_bar_height_pct(_value, bar_top_pct), do: bar_top_pct

  defp description_text(%{schedule_marker: %{present?: true}}),
    do: "View content students have completed compared to the schedule (dashed line)."

  defp description_text(_projection), do: "View content students have completed."

  defp bar_accessible_label(item, projected) do
    "#{item.label}. #{item.value_text}. Completion threshold #{projected.completion_threshold}%."
  end

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

  defp mode_label(:count), do: "#"
  defp mode_label(:percent), do: "%"

  defp tick_label(value, :percent), do: "#{value}"
  defp tick_label(value, _mode), do: Integer.to_string(value)

  defp hover_value_text(value, :percent), do: "#{Float.round(value, 1)}%"
  defp hover_value_text(value, _mode), do: Integer.to_string(round(value))

  defp truncate_label(label) do
    if String.length(label) > 9 do
      String.slice(label, 0, 7) <> "..."
    else
      label
    end
  end

  defp item_value_text(item, :percent), do: "#{item.percent}% of class"
  defp item_value_text(item, _mode), do: "#{item.count} students"
end
