defmodule Oli.InstructorDashboard.Prototype.Tiles.Progress.Data do
  @moduledoc """
  Non-UI projection logic for the Progress tile.
  """

  alias Oli.InstructorDashboard.Prototype.Oracles
  alias Oli.InstructorDashboard.Prototype.Snapshot
  alias Oli.InstructorDashboard.Prototype.Scope

  @default_per_page 7
  @empty_schedule %{present?: false}

  def build(%Snapshot{} = snapshot) do
    with {:ok, progress_payload} <- Snapshot.fetch_oracle(snapshot, Oracles.Progress),
         {:ok, contents_payload} <- Snapshot.fetch_oracle(snapshot, Oracles.Contents) do
      schedule_payload = optional_oracle(snapshot, :schedule)

      {:ok,
       build_projection(snapshot.scope, progress_payload, contents_payload, schedule_payload)}
    end
  end

  # Reprojects visible values from the precomputed per-item progress bins.
  def reproject(base_projection, tile_state \\ %{}) do
    threshold = Map.get(tile_state, :completion_threshold, base_projection.completion_threshold)
    y_axis_mode = Map.get(tile_state, :y_axis_mode, base_projection.y_axis_mode)
    per_page = Map.get(tile_state, :per_page, base_projection.page_window.per_page)

    enriched_series =
      Enum.map(base_projection.series_all, fn item ->
        count = count_at_or_above(item.bins, threshold)
        item = %{item | count: count, percent: percent(count, item.total)}
        Map.put(item, :value, value_for_mode(item, y_axis_mode))
      end)

    page_window = build_page_window(enriched_series, Map.get(tile_state, :page, 1), per_page)

    %{
      axis_label: base_projection.axis_label,
      class_size: base_projection.class_size,
      completion_threshold: threshold,
      y_axis_mode: y_axis_mode,
      series: page_series(enriched_series, page_window),
      series_all: enriched_series,
      schedule_context: base_projection.schedule_context,
      page_window: page_window,
      schedule_marker:
        schedule_marker(base_projection.schedule_context, enriched_series, page_window),
      empty_state: empty_state(enriched_series, base_projection.class_size)
    }
  end

  defp build_projection(%Scope{} = scope, progress_payload, contents_payload, schedule_payload) do
    items = Map.get(contents_payload, :items, [])

    threshold =
      Map.get(scope.filters, :completion_threshold, Scope.default_filters().completion_threshold)

    total_students = length(Map.get(progress_payload, :student_ids, []))

    # Each item represents one direct child of the current scope and keeps its
    # own resource type even when the axis label falls back to "Course Content".
    series_all =
      Enum.map(items, fn item ->
        bins = bins_for_item(progress_payload, item)

        %{
          container_id: item.resource_id,
          label: item.title,
          resource_type: item.resource_type_id,
          bins: bins,
          total: total_students,
          count: 0,
          percent: 0.0,
          value: 0
        }
      end)

    %{
      axis_label: axis_label(items),
      class_size: total_students,
      completion_threshold: threshold,
      y_axis_mode: :count,
      series_all: series_all,
      schedule_context: schedule_context(schedule_payload),
      page_window: build_page_window(series_all, 1, @default_per_page),
      schedule_marker: @empty_schedule,
      empty_state: empty_state(series_all, total_students)
    }
    |> reproject(%{})
  end

  defp optional_oracle(%Snapshot{} = snapshot, key) do
    Map.get(snapshot.oracle_payloads, key)
  end

  defp bins_for_item(progress_payload, %{
         resource_id: resource_id,
         resource_type_id: resource_type
       }) do
    progress_payload
    |> Map.get(:by_container, %{})
    |> Map.get(resource_type, %{})
    |> Map.get(resource_id, %{})
    |> student_progress_to_bins()
  end

  # Buckets progress into 10-point increments so threshold changes can be
  # recomputed without reloading raw per-student values.
  defp student_progress_to_bins(student_progress) do
    Enum.reduce(student_progress, %{}, fn {_student_id, progress}, acc ->
      bucket = bucket(progress)
      Map.update(acc, bucket, 1, &(&1 + 1))
    end)
  end

  defp bucket(progress) when progress >= 100, do: 100
  defp bucket(progress) when progress <= 0, do: 0
  defp bucket(progress), do: progress |> Kernel./(10) |> Float.ceil() |> trunc() |> Kernel.*(10)

  defp axis_label([]), do: "Course Content"

  defp axis_label(items) do
    types =
      items
      |> Enum.map(& &1.resource_type_id)
      |> Enum.uniq()

    case types do
      [:unit] -> "Course Units"
      [:module] -> "Course Modules"
      [:page] -> "Course Pages"
      [_single_type] -> "Course Content"
      _ -> "Course Content"
    end
  end

  defp count_at_or_above(bins, threshold) do
    bins
    |> Enum.reduce(0, fn {bucket, count}, acc ->
      if bucket >= threshold, do: acc + count, else: acc
    end)
  end

  defp value_for_mode(item, :percent), do: item.percent
  defp value_for_mode(item, _mode), do: item.count

  defp build_page_window(series, requested_page, per_page) do
    total_items = length(series)
    total_pages = if total_items == 0, do: 0, else: div(total_items + per_page - 1, per_page)
    page = clamp_page(requested_page, total_pages)

    %{
      page: page,
      per_page: per_page,
      total_items: total_items,
      total_pages: total_pages
    }
  end

  defp clamp_page(_requested_page, 0), do: 0
  defp clamp_page(requested_page, total_pages), do: requested_page |> max(1) |> min(total_pages)

  defp page_series(_series, %{page: 0}), do: []

  defp page_series(series, %{page: page, per_page: per_page}) do
    offset = (page - 1) * per_page
    Enum.slice(series, offset, per_page)
  end

  defp schedule_context(%{
         current_resource_id: current_resource_id,
         label: label,
         tooltip: tooltip
       })
       when not is_nil(current_resource_id) and is_binary(label) and is_binary(tooltip) do
    %{
      current_resource_id: current_resource_id,
      label: label,
      tooltip: tooltip
    }
  end

  defp schedule_context(_payload), do: nil

  defp schedule_marker(nil, _series, _page_window), do: @empty_schedule

  # The marker tracks which page contains the scheduled item and whether it is
  # visible in the current paginated slice.
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
