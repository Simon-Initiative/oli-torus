defmodule OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.ProgressTileTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.ProgressTile

  test "renders chart hook, controls, and class size" do
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
    assert html =~ ~s(data-role="progress-class-size")
    assert html =~ "24"
    assert html =~ "Completion Threshold"
    assert html =~ "phx-hook=\"ProgressTileChart\""
    assert html =~ "Course Units"
    assert html =~ "View Progress Details"
  end

  test "renders visible schedule marker and mixed axis copy" do
    html =
      render_component(ProgressTile,
        id: "progress_tile",
        projection: scheduled_projection(),
        tile_state: %{completion_threshold: 100, y_axis_mode: :count, page: 1},
        params: %{"dashboard_scope" => "course"},
        section_slug: "biology-101",
        dashboard_scope: "course"
      )

    assert html =~ "Schedule: Unit 2"
    assert html =~ "Course Content"
    assert html =~ "Completion threshold 100%"
    refute html =~ "Schedule is currently at Unit 2"
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

    assert html =~ "Unit 8"
    refute html =~ "Unit 1"
    assert html =~ "% of class"
    refute html =~ "Showing page 2 of 2"
  end

  test "keeps the count y-axis scale stable across paginated pages" do
    html =
      render_component(ProgressTile,
        id: "progress_tile",
        projection: paginated_projection(),
        tile_state: %{completion_threshold: 100, y_axis_mode: :count, page: 2},
        params: %{
          "dashboard_scope" => "course",
          "tile_progress" => %{"mode" => "count", "page" => "2"}
        },
        section_slug: "biology-101",
        dashboard_scope: "course"
      )

    assert html =~ ~r/>\s*30\s*</
    assert html =~ ~r/>\s*8\s*</
    assert html =~ "Unit 8"
    refute html =~ "Showing page 2 of 2"
  end

  test "uses class size as the count axis ceiling when present" do
    html =
      render_component(ProgressTile,
        id: "progress_tile",
        projection: small_class_projection(),
        tile_state: %{completion_threshold: 100, y_axis_mode: :count, page: 1},
        params: %{"dashboard_scope" => "course"},
        section_slug: "biology-101",
        dashboard_scope: "course"
      )

    assert html =~ ~r/>\s*8\s*</
    assert html =~ "height: 25.0%"
  end

  test "uses a friendly ceiling above larger class sizes" do
    html =
      render_component(ProgressTile,
        id: "progress_tile",
        projection: large_class_projection(),
        tile_state: %{completion_threshold: 100, y_axis_mode: :count, page: 1},
        params: %{"dashboard_scope" => "course"},
        section_slug: "biology-101",
        dashboard_scope: "course"
      )

    assert html =~ ~r/>\s*750\s*</
  end

  test "shades prior pages completely when the schedule marker is on a later page" do
    html =
      render_component(ProgressTile,
        id: "progress_tile",
        projection: paginated_scheduled_projection(),
        tile_state: %{completion_threshold: 100, y_axis_mode: :count, page: 1},
        params: %{
          "dashboard_scope" => "course",
          "tile_progress" => %{"mode" => "count", "page" => "1"}
        },
        section_slug: "biology-101",
        dashboard_scope: "course"
      )

    assert html =~ "width: 100.0%"
    refute html =~ "Schedule: Unit 8"
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

  defp scheduled_projection do
    %{
      axis_label: "Course Content",
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
          resource_type: :page,
          bins: %{100 => 6},
          total: 24,
          count: 0,
          percent: 0.0,
          value: 0
        }
      ],
      schedule_context: %{
        current_resource_id: 2,
        label: "Schedule: Unit 2",
        tooltip: "Schedule is currently at Unit 2"
      },
      page_window: %{page: 1, per_page: 7, total_items: 0, total_pages: 0},
      schedule_marker: %{present?: false}
    }
  end

  defp paginated_projection do
    %{
      axis_label: "Course Units",
      class_size: 30,
      completion_threshold: 100,
      y_axis_mode: :count,
      series_all:
        Enum.map(1..8, fn idx ->
          %{
            container_id: idx,
            label: "Unit #{idx}",
            resource_type: :container,
            bins: %{100 => if(idx == 1, do: 18, else: idx)},
            total: 30,
            count: 0,
            percent: 0.0,
            value: 0
          }
        end),
      schedule_context: nil,
      page_window: %{page: 1, per_page: 7, total_items: 0, total_pages: 0}
    }
  end

  defp paginated_scheduled_projection do
    paginated_projection()
    |> Map.put(:schedule_context, %{
      current_resource_id: 8,
      label: "Schedule: Unit 8",
      tooltip: "Schedule is currently at Unit 8"
    })
  end

  defp small_class_projection do
    %{
      axis_label: "Course Units",
      class_size: 8,
      completion_threshold: 100,
      y_axis_mode: :count,
      series_all: [
        %{
          container_id: 1,
          label: "Unit 1",
          resource_type: :container,
          bins: %{100 => 2},
          total: 8,
          count: 0,
          percent: 0.0,
          value: 0
        }
      ],
      schedule_context: nil,
      page_window: %{page: 1, per_page: 7, total_items: 0, total_pages: 0}
    }
  end

  defp large_class_projection do
    %{
      axis_label: "Course Units",
      class_size: 738,
      completion_threshold: 100,
      y_axis_mode: :count,
      series_all: [
        %{
          container_id: 1,
          label: "Unit 1",
          resource_type: :container,
          bins: %{100 => 412},
          total: 738,
          count: 0,
          percent: 0.0,
          value: 0
        }
      ],
      schedule_context: nil,
      page_window: %{page: 1, per_page: 7, total_items: 0, total_pages: 0}
    }
  end
end
