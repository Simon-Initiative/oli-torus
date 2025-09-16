defmodule OliWeb.Components.Delivery.AssignmentsListTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.AssignmentsList

  describe "render/1" do
    test "renders assignments list with title and description" do
      assignments = [
        %{
          id: 1,
          title: "Assignment 1",
          end_date: ~N[2024-01-15 23:59:59],
          relates_to: [],
          slug: "assignment-1",
          scheduled_type: :due_by
        },
        %{
          id: 2,
          title: "Assignment 2",
          end_date: ~N[2024-01-20 23:59:59],
          relates_to: [],
          slug: "assignment-2",
          scheduled_type: :due_by
        }
      ]

      assigns = %{
        assignments: assignments,
        section_slug: "test-section",
        format_datetime_fn: fn _ -> "Jan 15, 2024" end,
        preview_mode: false
      }

      html = render_component(&AssignmentsList.render/1, assigns)

      assert html =~ "Assignments"

      assert html =~
               "Find all your assignments, quizzes and activities associated with graded material."

      assert html =~ "Assignment 1"
      assert html =~ "Assignment 2"
    end

    test "renders empty list when no assignments" do
      assigns = %{
        assignments: [],
        section_slug: "test-section",
        format_datetime_fn: fn _ -> "Jan 15, 2024" end,
        preview_mode: false
      }

      html = render_component(&AssignmentsList.render/1, assigns)

      assert html =~ "Assignments"

      assert html =~
               "Find all your assignments, quizzes and activities associated with graded material."

      refute html =~ "Assignment 1"
    end

    test "passes correct props to AssignmentCard components" do
      assignments = [
        %{
          id: 1,
          title: "Test Assignment",
          end_date: ~N[2024-01-15 23:59:59],
          relates_to: [],
          slug: "test-assignment",
          scheduled_type: :due_by
        }
      ]

      assigns = %{
        assignments: assignments,
        section_slug: "test-section",
        format_datetime_fn: fn _ -> "Jan 15, 2024" end,
        preview_mode: true
      }

      html = render_component(&AssignmentsList.render/1, assigns)

      # Should render AssignmentCard with correct props
      assert html =~ "Test Assignment"
      assert html =~ "test-section"
    end
  end
end
