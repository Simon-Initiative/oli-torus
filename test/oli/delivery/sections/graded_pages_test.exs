defmodule Oli.Delivery.Sections.GradedPagesTest do
  use Oli.DataCase

  alias Oli.Delivery.Sections

  describe "graded pages" do
    setup [:section_with_deadlines]

    test "returns the graded pages in the correct order", %{section: section} do
      graded_pages = Sections.get_graded_pages(section.slug, 1)

      assert Enum.at(graded_pages, 0).title == "Graded page 4 - Level 0 (w/ gating condition)"
      assert Enum.at(graded_pages, 0).end_date == ~U[2023-01-12 13:30:00Z]

      assert Enum.at(graded_pages, 1).title ==
               "Graded page 5 - Level 0 (w/ student gating condition)"

      assert Enum.at(graded_pages, 1).end_date == ~U[2023-06-05 14:00:00Z]

      assert Enum.at(graded_pages, 2).title == "Graded page 1 - Level 1 (w/ no date)"
      assert Enum.at(graded_pages, 2)[:end_date] == nil

      assert Enum.at(graded_pages, 3).title == "Graded page 2 - Level 0 (w/ date)"
      assert Enum.at(graded_pages, 3)[:end_date] == nil

      assert Enum.at(graded_pages, 4).title == "Graded page 3 - Level 1 (w/ no date)"
      assert Enum.at(graded_pages, 4)[:end_date] == nil

      assert Enum.at(graded_pages, 5).title ==
               "Graded page 6 - Level 0 (w/o student gating condition)"

      assert Enum.at(graded_pages, 5)[:end_date] == nil

      assert Enum.at(graded_pages, 6).title == "Unreachable Graded page 2"
      assert Enum.at(graded_pages, 6)[:end_date] == nil

      assert Enum.at(graded_pages, 7).title == "Unreachable Graded page 1"
      assert Enum.at(graded_pages, 7)[:end_date] == nil
    end
  end
end
