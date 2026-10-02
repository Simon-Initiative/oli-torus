defmodule OliWeb.Grades.GradebookTableModelTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias OliWeb.Common.Table.ColumnSpec
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

    test "renders low scores with the shared assessment score warning logic" do
      row = %{
        score: 3,
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

      assert html =~ "text-red-500"
      assert html =~ ~s(aria-label="Assessment score below threshold")
      assert html =~ "stroke-current"
    end
  end

  describe "render_score/3" do
    test "renders low rolled-up scores with the red warning icon" do
      row =
        %{
          id: 1,
          section: %{slug: "test_section"}
        }
        |> Map.put(10, %ResourceAccess{
          resource_id: 10,
          user_id: 1,
          section_id: 1,
          score: 3,
          out_of: 10,
          resource_attempts_count: 1,
          was_late: false
        })

      html =
        Phoenix.HTML.Safe.to_iodata(
          GradebookTableModel.render_score(%{show_all_links: true}, row, %ColumnSpec{name: 10})
        )
        |> IO.iodata_to_binary()

      assert html =~ "text-Text-text-danger"
      assert html =~ ~s(aria-label="Assessment score below threshold")
      assert html =~ "stroke-current"
      assert html =~ "/10"

      assert html =~ "inline-flex items-center gap-1 whitespace-nowrap"
      assert html =~ ~r/3\s*<span class="text-Text-text-high">\/10<\/span>/
    end

    test "renders missing resource access as linked No Attempt" do
      row = %{id: 1, section: %{slug: "test_section"}}
      assigns = %{show_all_links: true}

      html =
        Phoenix.HTML.Safe.to_iodata(
          GradebookTableModel.render_score(assigns, row, %ColumnSpec{name: 10})
        )
        |> IO.iodata_to_binary()

      assert html =~ "No Attempt"
      assert html =~ ~s(href="/sections/test_section/progress/1/10")
      refute html =~ "Never Visited"
    end

    test "renders visited assessment with no started attempts as linked No Attempt" do
      row =
        %{
          id: 1,
          section: %{slug: "test_section"}
        }
        |> Map.put(10, %ResourceAccess{
          resource_id: 10,
          user_id: 1,
          section_id: 1,
          score: nil,
          out_of: nil,
          resource_attempts_count: 0
        })

      html =
        Phoenix.HTML.Safe.to_iodata(
          GradebookTableModel.render_score(%{show_all_links: true}, row, %ColumnSpec{name: 10})
        )
        |> IO.iodata_to_binary()

      assert html =~ "No Attempt"
      assert html =~ ~s(href="/sections/test_section/progress/1/10")
      refute html =~ "Not Finished"
    end

    test "renders missing resource access as an empty cell when links are disabled" do
      row = %{id: 1, section: %{slug: "test_section"}}

      html =
        Phoenix.HTML.Safe.to_iodata(
          GradebookTableModel.render_score(%{show_all_links: false}, row, %ColumnSpec{name: 10})
        )
        |> IO.iodata_to_binary()

      assert html == ""
    end

    test "renders started but unsubmitted attempt as an empty cell when links are disabled" do
      row =
        %{
          id: 1,
          section: %{slug: "test_section"}
        }
        |> Map.put(10, %ResourceAccess{
          resource_id: 10,
          user_id: 1,
          section_id: 1,
          score: nil,
          out_of: nil,
          resource_attempts_count: 1
        })

      html =
        Phoenix.HTML.Safe.to_iodata(
          GradebookTableModel.render_score(%{show_all_links: false}, row, %ColumnSpec{name: 10})
        )
        |> IO.iodata_to_binary()

      assert html == ""
    end

    test "renders started but unsubmitted attempt as linked Not Finished" do
      row =
        %{
          id: 1,
          section: %{slug: "test_section"}
        }
        |> Map.put(10, %ResourceAccess{
          resource_id: 10,
          user_id: 1,
          section_id: 1,
          score: nil,
          out_of: nil,
          resource_attempts_count: 1
        })

      html =
        Phoenix.HTML.Safe.to_iodata(
          GradebookTableModel.render_score(%{show_all_links: true}, row, %ColumnSpec{name: 10})
        )
        |> IO.iodata_to_binary()

      assert html =~ "Not Finished"
      assert html =~ ~s(href="/sections/test_section/progress/1/10")
    end
  end
end
