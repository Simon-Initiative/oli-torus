defmodule OliWeb.Grades.GradebookTableModelTest do
  use ExUnit.Case, async: true

  alias OliWeb.Grades.GradebookTableModel

  describe "render_grade_score/3" do
    test "formats scores to 2 decimal places" do
      row = %{
        score: 8.123456789,
        out_of: 10.987654321,
        resource_id: 1,
        was_late: false
      }

      assigns = %{
        section_slug: "test_section",
        student_id: 1
      }

      # Render the score
      html =
        Phoenix.HTML.Safe.to_iodata(GradebookTableModel.render_grade_score(assigns, row, %{}))
        |> IO.iodata_to_binary()

      assert html =~ "8.12/10.99"
    end

    test "handles integer scores correctly" do
      row = %{
        score: 8,
        out_of: 10,
        resource_id: 1,
        was_late: false
      }

      assigns = %{
        section_slug: "test_section",
        student_id: 1
      }

      html =
        Phoenix.HTML.Safe.to_iodata(GradebookTableModel.render_grade_score(assigns, row, %{}))
        |> IO.iodata_to_binary()

      assert html =~ "8/10"
    end

    test "handles nil scores correctly" do
      row = %{
        score: nil,
        out_of: 10,
        resource_id: 1,
        was_late: false
      }

      assigns = %{
        section_slug: "test_section",
        student_id: 1
      }

      html =
        Phoenix.HTML.Safe.to_iodata(GradebookTableModel.render_grade_score(assigns, row, %{}))
        |> IO.iodata_to_binary()

      assert html =~ "Not Finished"
    end
  end
end
