defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.ProgressTileTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.ProgressTile

  test "renders projected class size and threshold state" do
    html =
      render_component(ProgressTile,
        id: "progress_tile",
        projection: base_projection(),
        tile_state: %{completion_threshold: 100, y_axis_mode: :count, page: 1},
        params: %{"dashboard_scope" => "course"},
        section_slug: "biology-101",
        dashboard_scope: "course"
      )

    assert html =~ "Class size:"
    assert html =~ ">24<"
    assert html =~ "Completion Threshold: 100%"
    assert html =~ "View Progress Details"
  end

  test "reprojects mode and page from tile-local state" do
    html =
      render_component(ProgressTile,
        id: "progress_tile",
        projection: paginated_projection(),
        tile_state: %{completion_threshold: 100, y_axis_mode: :percent, page: 2},
        params: %{
          "dashboard_scope" => "course",
          "tile_progress" => %{"mode" => "percent", "page" => "2"}
        },
        section_slug: "biology-101",
        dashboard_scope: "course"
      )

    assert html =~ "Showing page 2 of 2"
    assert html =~ "Unit 8"
    refute html =~ "Unit 1"
    assert html =~ "% of class"
  end

  defp base_projection do
    %{
      axis_label: "Course Units",
      class_size: 24,
      completion_threshold: 100,
      y_axis_mode: :count,
      series_all: [
        %{
          container_id: 1,
          label: "Unit 1",
          resource_type: :container,
          bins: %{100 => 12},
          total: 24,
          count: 0,
          percent: 0.0,
          value: 0
        },
        %{
          container_id: 2,
          label: "Unit 2",
          resource_type: :container,
          bins: %{100 => 6},
          total: 24,
          count: 0,
          percent: 0.0,
          value: 0
        }
      ],
      schedule_context: nil,
      page_window: %{page: 1, per_page: 7, total_items: 0, total_pages: 0}
    }
  end

  defp paginated_projection do
    %{
      axis_label: "Course Units",
      class_size: 10,
      completion_threshold: 100,
      y_axis_mode: :count,
      series_all:
        Enum.map(1..8, fn idx ->
          %{
            container_id: idx,
            label: "Unit #{idx}",
            resource_type: :container,
            bins: %{100 => idx},
            total: 10,
            count: 0,
            percent: 0.0,
            value: 0
          }
        end),
      schedule_context: nil,
      page_window: %{page: 1, per_page: 7, total_items: 0, total_pages: 0}
    }
  end
end
