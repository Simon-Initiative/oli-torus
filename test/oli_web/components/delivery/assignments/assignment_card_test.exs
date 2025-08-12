defmodule OliWeb.Components.Delivery.AssignmentCardTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.AssignmentCard

  describe "render/1" do
    test "renders assignment card with basic information" do
      assignment = %{
        id: 1,
        title: "Test Assignment",
        end_date: ~N[2024-01-15 23:59:59],
        relates_to: [],
        slug: "test-assignment",
        scheduled_type: :due_by
      }

      assigns = %{
        assignment: assignment,
        section_slug: "test-section",
        format_datetime_fn: fn _ -> "Jan 15, 2024" end,
        preview_mode: false
      }

      html = render_component(&AssignmentCard.render/1, assigns)

      assert html =~ "Test Assignment"
      assert html =~ "Due by Jan 15, 2024"
      assert html =~ "Open"
      assert html =~ "disabled"
    end

    test "renders assignment with no due date" do
      assignment = %{
        id: 1,
        title: "Test Assignment",
        end_date: nil,
        relates_to: [],
        slug: "test-assignment",
        scheduled_type: :due_by
      }

      assigns = %{
        assignment: assignment,
        section_slug: "test-section",
        format_datetime_fn: fn _ -> "Jan 15, 2024" end,
        preview_mode: false
      }

      html = render_component(&AssignmentCard.render/1, assigns)

      assert html =~ "No due date"
    end

    test "renders assignment with read_by scheduled type" do
      assignment = %{
        id: 1,
        title: "Test Assignment",
        end_date: ~N[2024-01-15 23:59:59],
        scheduled_type: :read_by,
        relates_to: [],
        slug: "test-assignment"
      }

      assigns = %{
        assignment: assignment,
        section_slug: "test-section",
        format_datetime_fn: fn _ -> "Jan 15, 2024" end,
        preview_mode: false
      }

      html = render_component(&AssignmentCard.render/1, assigns)

      assert html =~ "Read by Jan 15, 2024"
    end

    test "renders assignment with in class activity scheduled type" do
      assignment = %{
        id: 1,
        title: "Test Assignment",
        end_date: ~N[2024-01-15 23:59:59],
        scheduled_type: :in_class,
        relates_to: [],
        slug: "test-assignment"
      }

      assigns = %{
        assignment: assignment,
        section_slug: "test-section",
        format_datetime_fn: fn _ -> "Jan 15, 2024" end,
        preview_mode: false
      }

      html = render_component(&AssignmentCard.render/1, assigns)

      assert html =~ "In class activity"
    end

    test "renders related pages when assignment has relates_to" do
      assignment = %{
        id: 1,
        title: "Test Assignment",
        end_date: ~N[2024-01-15 23:59:59],
        relates_to: [
          %{
            title: "Foundation Page",
            purpose: :foundation,
            progress: 0.75,
            slug: "foundation-page"
          },
          %{
            title: "Exploration Page",
            purpose: :application,
            progress: 0.5,
            slug: "exploration-page"
          }
        ],
        slug: "test-assignment",
        scheduled_type: :due_by
      }

      assigns = %{
        assignment: assignment,
        section_slug: "test-section",
        format_datetime_fn: fn _ -> "Jan 15, 2024" end,
        preview_mode: false
      }

      html = render_component(&AssignmentCard.render/1, assigns)

      assert html =~ "Quiz covers"
      assert html =~ "Course content"
      assert html =~ "Explorations"
      assert html =~ "Foundation Page"
      assert html =~ "Exploration Page"
      assert html =~ "75.0% Completed"
      assert html =~ "50.0% Completed"
    end

    test "renders pages with no progress as not attempted" do
      assignment = %{
        id: 1,
        title: "Test Assignment",
        end_date: ~N[2024-01-15 23:59:59],
        relates_to: [
          %{
            title: "No Progress Page",
            purpose: :foundation,
            progress: nil,
            slug: "no-progress-page"
          }
        ],
        slug: "test-assignment",
        scheduled_type: :due_by
      }

      assigns = %{
        assignment: assignment,
        section_slug: "test-section",
        format_datetime_fn: fn _ -> "Jan 15, 2024" end,
        preview_mode: false
      }

      html = render_component(&AssignmentCard.render/1, assigns)

      assert html =~ "Not attempted"
      assert html =~ "text-red-600"
    end

    test "generates correct preview mode URL" do
      assignment = %{
        id: 1,
        title: "Test Assignment",
        end_date: ~N[2024-01-15 23:59:59],
        relates_to: [],
        slug: "test-assignment",
        scheduled_type: :due_by
      }

      assigns = %{
        assignment: assignment,
        section_slug: "test-section",
        format_datetime_fn: fn _ -> "Jan 15, 2024" end,
        preview_mode: true
      }

      html = render_component(&AssignmentCard.render/1, assigns)

      assert html =~ "/sections/test-section/preview/page/test-assignment"
    end

    test "generates correct delivery mode URL" do
      assignment = %{
        id: 1,
        title: "Test Assignment",
        end_date: ~N[2024-01-15 23:59:59],
        relates_to: [],
        slug: "test-assignment",
        scheduled_type: :due_by
      }

      assigns = %{
        assignment: assignment,
        section_slug: "test-section",
        format_datetime_fn: fn _ -> "Jan 15, 2024" end,
        preview_mode: false
      }

      html = render_component(&AssignmentCard.render/1, assigns)

      assert html =~ "/sections/test-section/page/test-assignment"
    end
  end

  describe "render_related_page_info/1" do
    test "renders related page information" do
      page = %{
        title: "Test Page",
        progress: 0.8,
        slug: "test-page"
      }

      assigns = %{
        page: page,
        section_slug: "test-section",
        preview_mode: false
      }

      html = render_component(&AssignmentCard.render_related_page_info/1, assigns)

      assert html =~ "Test Page"
      assert html =~ "80.0% Completed"
      assert html =~ "Open"
    end

    test "renders page with no progress" do
      page = %{
        title: "Test Page",
        progress: nil,
        slug: "test-page"
      }

      assigns = %{
        page: page,
        section_slug: "test-section",
        preview_mode: false
      }

      html = render_component(&AssignmentCard.render_related_page_info/1, assigns)

      assert html =~ "Not attempted"
      assert html =~ "text-red-600"
    end
  end
end
