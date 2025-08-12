defmodule OliWeb.Components.Delivery.UpNextTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.UpNext

  describe "up_next/1" do
    test "renders up next with user and activities" do
      assigns = %{
        user: %{name: "John Doe"},
        next_activities: [
          %{
            title: "Activity 1",
            graded: true,
            progress: 50,
            end_date: "2024-01-01",
            slug: "a1",
            scheduling_type: "Due by",
            completion_percentage: 80.0
          },
          %{
            title: "Activity 2",
            graded: false,
            progress: 100,
            end_date: "2024-01-02",
            slug: "a2",
            scheduling_type: "Read by",
            completion_percentage: 100.0
          }
        ],
        section_slug: "section"
      }

      html = render_component(&UpNext.up_next/1, assigns)
      assert html =~ "Up Next for"
      # The user name is rendered in a span with font-bold class
      assert html =~ "font-bold"
      assert html =~ "Activity 1"
      assert html =~ "Activity 2"
      assert html =~ "Graded Assignment"
      assert html =~ "Course Content"
    end
  end

  describe "card/1" do
    test "renders card with all attributes" do
      assigns = %{
        badge_name: "Graded Assignment",
        badge_bg_color: "bg-fuchsia-800",
        title: "Activity 1",
        percent_complete: 50,
        complete_by_date: "2024-01-01",
        open_href: "/page/section/a1",
        percent_students_completed: 80,
        scheduling_type: "Due by",
        request_extension_href: "/request-extension"
      }

      html = render_component(&UpNext.card/1, assigns)
      assert html =~ "Graded Assignment"
      assert html =~ "Activity 1"
      assert html =~ "50"
      assert html =~ "2024-01-01"
      assert html =~ "Open"
      assert html =~ "80% of students have completed this content"
      assert html =~ "Request Extension"
      assert html =~ "Due by"
    end

    test "renders card without optional attributes" do
      assigns = %{
        badge_name: "Course Content",
        badge_bg_color: "bg-green-700",
        title: "Activity 2",
        percent_complete: 100,
        complete_by_date: "2024-01-02",
        open_href: "/page/section/a2",
        percent_students_completed: 100,
        scheduling_type: "Read by"
      }

      html = render_component(&UpNext.card/1, assigns)
      assert html =~ "Course Content"
      assert html =~ "Activity 2"
      assert html =~ "100"
      assert html =~ "2024-01-02"
      assert html =~ "Open"
      assert html =~ "100% of students have completed this content"
      assert html =~ "Read by"
    end

    test "renders card with minimal attributes" do
      assigns = %{
        badge_name: "Course Content",
        badge_bg_color: "bg-green-700",
        title: "Activity 3",
        percent_complete: 0,
        complete_by_date: "2024-01-03",
        open_href: "/page/section/a3",
        percent_students_completed: 0,
        scheduling_type: "Read by"
      }

      html = render_component(&UpNext.card/1, assigns)
      assert html =~ "Course Content"
      assert html =~ "Activity 3"
      assert html =~ "0"
      assert html =~ "2024-01-03"
      assert html =~ "Open"
      assert html =~ "0% of students have completed this content"
      assert html =~ "Read by"
    end
  end
end
