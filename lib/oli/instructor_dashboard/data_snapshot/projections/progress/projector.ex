defmodule Oli.InstructorDashboard.DataSnapshot.Projections.Progress.Projector do
  @moduledoc false

  alias Oli.Dashboard.Scope
  alias Oli.Resources.ResourceType

  @default_completion_threshold 100
  @default_per_page 7
  @empty_schedule %{present?: false}
  @page_type_id ResourceType.id_for_page()
  @container_type_id ResourceType.id_for_container()

  @spec build(Scope.t(), map(), map(), keyword()) :: map()
  def build(%Scope{} = scope, progress_bins_payload, scope_resources_payload, opts \\ []) do
    items = Map.get(scope_resources_payload, :items, [])
    total_students = Map.get(progress_bins_payload, :total_students, 0)

    %{
      axis_label: axis_label(scope, items),
      class_size: total_students,
      completion_threshold: @default_completion_threshold,
      y_axis_mode: :count,
      series_all: build_series(items, progress_bins_payload, total_students),
      schedule_context: schedule_context(Keyword.get(opts, :schedule)),
      page_window: %{page: 1, per_page: @default_per_page, total_items: 0, total_pages: 0},
      schedule_marker: @empty_schedule,
      empty_state: nil
    }
  end

  @spec reproject(map(), map()) :: map()
  def reproject(base_projection, tile_state \\ %{}) do
    threshold = Map.get(tile_state, :completion_threshold, base_projection.completion_threshold)
    y_axis_mode = Map.get(tile_state, :y_axis_mode, base_projection.y_axis_mode)
    per_page = get_in(base_projection, [:page_window, :per_page]) || @default_per_page

    enriched_series =
      Enum.map(Map.get(base_projection, :series_all, []), fn item ->
        count = count_at_or_above(item.bins, threshold)
        item = %{item | count: count, percent: percent(count, item.total)}
        Map.put(item, :value, value_for_mode(item, y_axis_mode))
      end)

    page_window = build_page_window(enriched_series, Map.get(tile_state, :page, 1), per_page)

    %{
      axis_label: Map.get(base_projection, :axis_label, "Course Content"),
      class_size: Map.get(base_projection, :class_size, 0),
      completion_threshold: threshold,
      y_axis_mode: y_axis_mode,
      series: page_series(enriched_series, page_window),
      series_all: enriched_series,
      schedule_context: Map.get(base_projection, :schedule_context),
      page_window: page_window,
      schedule_marker:
        schedule_marker(Map.get(base_projection, :schedule_context), enriched_series, page_window),
      empty_state: empty_state(enriched_series, Map.get(base_projection, :class_size, 0))
    }
  end

  defp build_series(items, progress_bins_payload, total_students) do
    by_container_bins = Map.get(progress_bins_payload, :by_container_bins, %{})

    Enum.map(items, fn item ->
      %{
        container_id: item.resource_id,
        label: item.title,
        resource_type: resource_type(item.resource_type_id),
        bins: Map.get(by_container_bins, item.resource_id, %{}),
        total: total_students,
        count: 0,
        percent: 0.0,
        value: 0
      }
    end)
  end

  defp resource_type(resource_type_id) when resource_type_id == @page_type_id, do: :page

  defp resource_type(resource_type_id) when resource_type_id == @container_type_id,
    do: :container

  defp resource_type(_resource_type_id), do: :unknown

  defp axis_label(_scope, []), do: "Course Content"

  defp axis_label(scope, items) do
    types = items |> Enum.map(&resource_type(&1.resource_type_id)) |> Enum.uniq()

    case types do
      [:page] -> "Course Pages"
      [:container] when scope.container_type == :course -> "Course Units"
      [:container] when scope.container_type == :container -> "Course Modules"
      _ -> "Course Content"
    end
  end

  defp count_at_or_above(bins, threshold) do
    Enum.reduce(bins, 0, fn {bucket, count}, acc ->
      if bucket >= threshold, do: acc + count, else: acc
    end)
  end

  defp value_for_mode(item, :percent), do: item.percent
  defp value_for_mode(item, _mode), do: item.count

  defp build_page_window(series, requested_page, per_page) do
    total_items = length(series)
    total_pages = if total_items == 0, do: 0, else: div(total_items + per_page - 1, per_page)
    page = clamp_page(requested_page, total_pages)

    %{page: page, per_page: per_page, total_items: total_items, total_pages: total_pages}
  end

  defp clamp_page(_requested_page, 0), do: 0
  defp clamp_page(requested_page, total_pages), do: requested_page |> max(1) |> min(total_pages)

  defp page_series(_series, %{page: 0}), do: []

  defp page_series(series, %{page: page, per_page: per_page}) do
    Enum.slice(series, (page - 1) * per_page, per_page)
  end

  defp schedule_context(%{
         current_resource_id: current_resource_id,
         label: label,
         tooltip: tooltip
       })
       when not is_nil(current_resource_id) and is_binary(label) and is_binary(tooltip) do
    %{current_resource_id: current_resource_id, label: label, tooltip: tooltip}
  end

  defp schedule_context(_payload), do: nil

  defp schedule_marker(nil, _series, _page_window), do: @empty_schedule

  defp schedule_marker(schedule_context, series, page_window) do
    with false <- page_window.page == 0,
         index when is_integer(index) <-
           Enum.find_index(series, &(&1.container_id == schedule_context.current_resource_id)) do
      marker_page = div(index, page_window.per_page) + 1

      %{
        present?: true,
        container_id: schedule_context.current_resource_id,
        label: schedule_context.label,
        tooltip: schedule_context.tooltip,
        page: marker_page,
        visible?: marker_page == page_window.page
      }
    else
      _ -> @empty_schedule
    end
  end

  defp empty_state([], _class_size), do: %{type: :no_scope_children}
  defp empty_state(_series, 0), do: %{type: :no_students}
  defp empty_state(_series, _class_size), do: nil

  defp percent(_count, 0), do: 0.0

  defp percent(count, total) do
    count
    |> Kernel./(total)
    |> Kernel.*(100)
    |> Float.round(1)
  end
end
