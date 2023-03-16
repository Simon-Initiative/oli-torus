defmodule Oli.Delivery.Sections.GradedPagesTest do
  use Oli.DataCase

  alias Oli.Delivery.Sections

  describe "graded pages" do
    setup [:section_with_gating_conditions]

    test "returns the graded pages in the correct order", %{section: section} do
      graded_pages = Sections.get_graded_pages(section.slug, 1)

      assert Enum.at(graded_pages, 0).title == "Graded page 4 - Level 0 (w/ gating condition)"
      assert Enum.at(graded_pages, 0).end_date == ~D[2023-01-12]

      assert Enum.at(graded_pages, 1).title ==
               "Graded page 5 - Level 0 (w/ student gating condition)"

      assert Enum.at(graded_pages, 1).end_date == ~D[2023-06-05]

      assert Enum.at(graded_pages, 2).title == "Graded page 1 - Level 1 (w/ no date)"
      assert Enum.at(graded_pages, 2)[:end_date] == nil

      assert Enum.at(graded_pages, 3).title == "Graded page 2 - Level 0 (w/ date)"
      assert Enum.at(graded_pages, 3)[:end_date] == nil

      assert Enum.at(graded_pages, 4).title == "Graded page 3 - Level 1 (w/ no date)"
      assert Enum.at(graded_pages, 5)[:end_date] == nil
    end

    test "when a gating condition exists for a student, it overrides the end date", %{
      section: section,
      student_with_gating_condition: student
    } do
      graded_pages = Sections.get_graded_pages(section.slug, student.id)

      assert Enum.at(graded_pages, 1).title ==
               "Graded page 5 - Level 0 (w/ student gating condition)"

      refute Enum.at(graded_pages, 1).end_date == ~D[2023-06-05]
      assert Enum.at(graded_pages, 1).end_date == ~D[2023-07-08]
    end
  end
end
