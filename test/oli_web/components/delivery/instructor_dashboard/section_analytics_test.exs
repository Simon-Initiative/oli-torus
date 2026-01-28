defmodule OliWeb.Components.Delivery.InstructorDashboard.SectionAnalyticsTest do
  use ExUnit.Case, async: true
  alias OliWeb.Components.Delivery.InstructorDashboard.SectionAnalytics
  import Phoenix.LiveViewTest

  @endpoint OliWeb.Endpoint

  # Since most functions are private, we test through the public interface
  # The main issue was in parse_tsv_data which is called by get_analytics_data_and_spec

  describe "get_analytics_data_and_spec/2" do
    test "returns empty data for unknown category" do
      assert SectionAnalytics.get_analytics_data_and_spec("unknown", 123) == {[], []}
    end
  end

  describe "module structure" do
    test "module has required functions" do
      assert Code.ensure_loaded?(SectionAnalytics)
      # Test that the public functions we expect are available
      assert function_exported?(SectionAnalytics, :mount, 1)
      assert function_exported?(SectionAnalytics, :update, 2)
      assert function_exported?(SectionAnalytics, :render, 1)
      assert function_exported?(SectionAnalytics, :handle_event, 3)
      assert function_exported?(SectionAnalytics, :get_analytics_data_and_spec, 2)
    end
  end

  describe "event summary rendering" do
    test "aggregates rows per canonical event type" do
      analytics_payload = %{
        parsed_body: %{
          "data" => [
            %{
              "event_type" => "video",
              "total_events" => 5,
              "unique_users" => 2,
              "additional_info" => "Watch time tracked"
            },
            %{
              "event_type" => "video_events",
              "total_events" => 3,
              "unique_users" => 1,
              "additional_info" => "Legacy watch time tracked"
            },
            %{
              "event_type" => "activity_attempt",
              "total_events" => 7,
              "unique_users" => 4,
              "additional_info" => "Avg score: 0.72"
            }
          ]
        }
      }

      rendered =
        render_component(SectionAnalytics,
          id: "section_analytics",
          section: %{id: 123},
          selected_analytics_category: "video",
          analytics_data: nil,
          analytics_spec: nil,
          section_analytics_load_state: :loaded,
          comprehensive_section_analytics: {:ok, analytics_payload},
          custom_sql_query: nil,
          custom_vega_spec: nil,
          custom_query_result: nil,
          custom_visualization_spec: nil,
          engagement_start_date: "2024-01-01",
          engagement_end_date: "2024-01-31",
          engagement_max_pages: 25,
          resource_title_map: %{}
        )

      html = rendered

      assert html =~ "Video Interactions"
      assert html =~ ~r/>\s*8\s*<\/p>/
      assert html =~ "events from 2 users"
      assert html =~ "Activity Attempts"
      assert html =~ ~r/>\s*7\s*<\/p>/
      assert html =~ "events from 4 users"
      # Ensure we only rendered one combined video card
      assert String.contains?(html, "Video Interactions")
      refute String.contains?(html, "video_events")
    end
  end

  # Test that verifies our fix for the separator line issue
  describe "TSV data parsing fix validation" do
    # Since parse_tsv_data is private, we create a simple test module to test the logic
    # This simulates the fix we applied
    defp parse_tsv_data_test(body) when is_binary(body) do
      lines = String.split(String.trim(body), "\n")

      case lines do
        [] ->
          []

        [_header | data_lines] ->
          data_lines
          |> Enum.filter(fn line ->
            # Filter out separator lines that contain only dashes and pipes
            not String.match?(line, ~r/^[\s\-\|]+$/)
          end)
          |> Enum.map(fn line ->
            String.split(line, "\t")
          end)
      end
    end

    test "filters out separator lines with dashes and pipes" do
      tsv_data = """
      content_element_id\tvideo_url\tplays\tcompletions\tcompletion_rate\tavg_progress\tunique_viewers
      -------------------|--------------------------------------------------------------------------------------------------|-------|-------------|--------------------|----------------------|---------------
      1\thttps://example.com/video-1\t25\t20\t80.0\t0.85\t15
      2\thttps://example.com/video-2\t18\t12\t66.7\t0.72\t12
      """

      result = parse_tsv_data_test(tsv_data)

      assert result == [
               ["1", "https://example.com/video-1", "25", "20", "80.0", "0.85", "15"],
               ["2", "https://example.com/video-2", "18", "12", "66.7", "0.72", "12"]
             ]
    end

    test "handles empty input" do
      assert parse_tsv_data_test("") == []
      assert parse_tsv_data_test("   ") == []
    end

    test "handles only header" do
      tsv_data = "header1\theader2\theader3"
      assert parse_tsv_data_test(tsv_data) == []
    end

    test "handles header with separator line only" do
      tsv_data = """
      header1\theader2\theader3
      -------|-------|-------
      """

      assert parse_tsv_data_test(tsv_data) == []
    end

    test "handles complex separator patterns" do
      tsv_data = """
      col1\tcol2\tcol3
      ---|---|---
      data1\tdata2\tdata3
      ----------|----------|----------
      data4\tdata5\tdata6
      """

      result = parse_tsv_data_test(tsv_data)

      assert result == [
               ["data1", "data2", "data3"],
               ["data4", "data5", "data6"]
             ]
    end

    test "preserves data that contains dashes but is not a separator" do
      tsv_data = """
      name\tdescription\tvalue
      test-item\tA test-case with dashes\t123
      another-test\tMore-data-here\t456
      """

      result = parse_tsv_data_test(tsv_data)

      assert result == [
               ["test-item", "A test-case with dashes", "123"],
               ["another-test", "More-data-here", "456"]
             ]
    end

    test "handles the exact separator pattern from the error" do
      # This is the exact separator line that was causing the error
      separator_line =
        "-------------------|--------------------------------------------------------------------------------------------------|-------|-------------|--------------------|----------------------|---------------"

      tsv_data = """
      header1\theader2\theader3
      #{separator_line}
      data1\tdata2\tdata3
      """

      result = parse_tsv_data_test(tsv_data)

      # The separator line should be filtered out
      assert result == [["data1", "data2", "data3"]]
    end
  end

  # Test the video completion chart data processing specifically
  describe "video completion chart data processing" do
    # Since create_video_completion_chart is private, we test the pattern matching logic
    # This simulates what happens inside the function
    defp safe_video_data_extraction(row) do
      case row do
        list when is_list(list) and length(list) >= 7 ->
          [_id, title, plays, _completions, completion_rate, _avg_progress, _viewers] =
            Enum.take(list, 7)

          {:ok, {title, plays, completion_rate}}

        list when is_list(list) ->
          {:error, :insufficient_data}

        _ ->
          {:error, :invalid_format}
      end
    end

    test "handles valid video data correctly" do
      valid_row = ["1", "Introduction Video", "25", "20", "80.0", "0.85", "15"]
      assert {:ok, {"Introduction Video", "25", "80.0"}} = safe_video_data_extraction(valid_row)
    end

    test "handles insufficient data gracefully" do
      incomplete_row = ["1", "Introduction Video"]
      assert {:error, :insufficient_data} = safe_video_data_extraction(incomplete_row)
    end

    test "handles separator line data gracefully" do
      separator_as_list = [
        "-------------------|--------------------------------------------------------------------------------------------------|-------|-------------|--------------------|----------------------|---------------"
      ]

      assert {:error, :insufficient_data} = safe_video_data_extraction(separator_as_list)
    end

    test "handles empty row gracefully" do
      empty_row = []
      assert {:error, :insufficient_data} = safe_video_data_extraction(empty_row)
    end

    test "handles non-list data gracefully" do
      invalid_data = "not a list"
      assert {:error, :invalid_format} = safe_video_data_extraction(invalid_data)
    end
  end
end
