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

  test "hides the chart from screen readers once every unit announces its value, units at 0 included" do
    below_threshold = %{
      container_id: 3,
      label: "Unit 3",
      resource_type: :container,
      bins: %{50 => 4},
      total: 24,
      count: 0,
      percent: 0.0,
      value: 0
    }

    projection = Map.update!(base_projection(), :series_all, &(&1 ++ [below_threshold]))
    doc = projection |> render_progress_tile(1) |> Floki.parse_document!()

    announced? = &String.ends_with?(&1, "Completion threshold 100%.")

    bar_buttons =
      doc |> Floki.find("button[aria-label]") |> Enum.flat_map(&Floki.attribute(&1, "aria-label"))

    screen_reader_texts = doc |> Floki.find(".sr-only") |> Enum.map(&String.trim(Floki.text(&1)))

    assert Enum.filter(bar_buttons, announced?) == [
             "Unit 1. 12 students. Completion threshold 100%.",
             "Unit 2. 6 students. Completion threshold 100%."
           ]

    assert Enum.filter(screen_reader_texts, announced?) == [
             "Unit 3. 0 students. Completion threshold 100%."
           ]

    assert [chart] = Floki.find(doc, "#progress-chart-wrapper-progress_tile")
    assert Floki.attribute(chart, "aria-hidden") == ["true"]
  end

  test "hides the icon beside the Progress heading from screen readers" do
    html =
      render_component(ProgressTile,
        id: "progress_tile",
        projection: base_projection(),
        tile_state: %{completion_threshold: 100, y_axis_mode: :count, page: 1},
        params: %{"dashboard_scope" => "course"},
        section_slug: "biology-101",
        dashboard_scope: "course"
      )

    [heading] =
      html
      |> Floki.parse_document!()
      |> Floki.find("div.items-center.gap-2")
      |> Enum.filter(&(&1 |> Floki.find("h3") |> Floki.text() |> String.trim() == "Progress"))

    assert [_icon] = Floki.find(heading, "svg")

    assert [_hidden_icon] =
             Floki.find(heading, ~s{svg[aria-hidden="true"], [aria-hidden="true"] svg})
  end

  test "hides the icon inside the completion threshold help button from screen readers but keeps the button's name" do
    doc = base_projection() |> render_progress_tile(1) |> Floki.parse_document!()

    assert [button] = Floki.find(doc, ~s{button[aria-label="Completion threshold help"]})
    assert [_icon] = Floki.find(button, "svg")

    assert [_hidden_icon] =
             Floki.find(button, ~s{svg[aria-hidden="true"], [aria-hidden="true"] svg})
  end

  test "hides the completion threshold selector's arrow from screen readers but keeps the selected value as its name" do
    doc = base_projection() |> render_progress_tile(1) |> Floki.parse_document!()

    assert [selector] = Floki.find(doc, "details summary")
    assert selector |> Floki.text() |> String.trim() == "100%"
    assert [_arrow] = Floki.find(selector, "svg")

    assert [_hidden_arrow] =
             Floki.find(selector, ~s{svg[aria-hidden="true"], [aria-hidden="true"] svg})
  end

  test "hides the arrows inside the chart's Previous page and Next page links from screen readers" do
    next_link =
      paginated_projection()
      |> render_progress_tile(1)
      |> Floki.parse_document!()
      |> Floki.find(~s{a[aria-label="Next page"]})

    previous_link =
      paginated_projection()
      |> render_progress_tile(2)
      |> Floki.parse_document!()
      |> Floki.find(~s{a[aria-label="Previous page"]})

    for link <- [next_link, previous_link] do
      assert [_arrow] = Floki.find(link, "svg")

      assert [_hidden_arrow] =
               Floki.find(link, ~s{svg[aria-hidden="true"], [aria-hidden="true"] svg})
    end
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

  defp render_progress_tile(projection, page) do
    render_component(ProgressTile,
      id: "progress_tile",
      projection: projection,
      tile_state: %{completion_threshold: 100, y_axis_mode: :count, page: page},
      params: %{"dashboard_scope" => "course"},
      section_slug: "biology-101",
      dashboard_scope: "course"
    )
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
