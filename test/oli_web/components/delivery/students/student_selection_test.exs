defmodule OliWeb.Components.Delivery.Students.StudentSelectionTest do
  use ExUnit.Case, async: true

  alias OliWeb.Components.Delivery.Students.StudentSelection

  describe "toggle/2" do
    test "adds an id that isn't currently selected" do
      assert StudentSelection.toggle([1, 2], 3) == [3, 1, 2]
    end

    test "removes an id that is currently selected" do
      assert StudentSelection.toggle([1, 2, 3], 2) == [1, 3]
    end

    test "adding to an empty selection" do
      assert StudentSelection.toggle([], 1) == [1]
    end
  end

  describe "toggle_all/2" do
    test "selects every id in all_ids when none are currently selected" do
      assert StudentSelection.toggle_all([1, 2, 3], []) |> Enum.sort() == [1, 2, 3]
    end

    test "selects only the ids in all_ids not already selected, preserving the rest" do
      assert StudentSelection.toggle_all([1, 2, 3], [2]) |> Enum.sort() == [1, 2, 3]
    end

    test "deselects every id in all_ids when all are already selected" do
      assert StudentSelection.toggle_all([1, 2], [1, 2, 3]) == [3]
    end

    test "leaves selections outside all_ids untouched when selecting" do
      assert StudentSelection.toggle_all([1, 2], [99]) |> Enum.sort() == [1, 2, 99]
    end

    test "an empty all_ids list is a no-op" do
      assert StudentSelection.toggle_all([], [1, 2]) == [1, 2]
    end
  end

  describe "recipients/3" do
    test "keeps selected students (incl. those without email) and sets display_name" do
      students = [
        %{
          id: 1,
          email: "a@example.edu",
          given_name: "A",
          family_name: "One",
          full_name: "One, A"
        },
        %{id: 2, email: nil, given_name: "B", family_name: "Two", full_name: "Two, B"},
        %{id: 3, email: "c@example.edu", full_name: "Three, C"}
      ]

      result = StudentSelection.recipients(students, [1, 2], & &1.full_name)

      assert [
               %{id: 1, email: "a@example.edu", display_name: "One, A"},
               %{id: 2, email: nil, display_name: "Two, B"}
             ] = result

      # Not-selected student is excluded; no-email student (2) is kept.
      assert Enum.map(result, & &1.id) == [1, 2]
      assert Enum.find(result, &(&1.id == 2)).given_name == "B"
    end
  end
end
