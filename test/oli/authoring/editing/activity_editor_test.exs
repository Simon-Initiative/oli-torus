defmodule Oli.Authoring.Editing.ActivityEditorTest do
  use ExUnit.Case, async: true

  alias Oli.Authoring.Editing.ActivityEditor

  describe "filter_objectives_to_existing/2" do
    test "removes objective ids that do not exist" do
      objectives = %{
        "part-1" => [1, 99, 2],
        "part-2" => [3]
      }

      all_objectives = [
        %{id: 1, title: "One", parentIds: []},
        %{id: 2, title: "Two", parentIds: []}
      ]

      assert ActivityEditor.filter_objectives_to_existing(objectives, all_objectives) == %{
               "part-1" => [1, 2],
               "part-2" => []
             }
    end

    test "keeps existing ids per part without touching structure" do
      objectives = %{"p1" => [2], "p2" => []}
      all_objectives = [%{id: 2, title: "Two", parentIds: [10]}]

      assert ActivityEditor.filter_objectives_to_existing(objectives, all_objectives) ==
               objectives
    end

    test "works with objective lists shaped like construct_parent_references/1 output" do
      objectives = %{"p1" => [11, 12]}

      all_objectives = [
        %{id: 11, title: "Child", parentIds: [5]},
        %{id: 12, title: "Child 2", parentIds: [5, 6]}
      ]

      assert ActivityEditor.filter_objectives_to_existing(objectives, all_objectives) ==
               objectives
    end

    test "returns empty map when objectives is not a map" do
      assert ActivityEditor.filter_objectives_to_existing(nil, []) == %{}
      assert ActivityEditor.filter_objectives_to_existing("not-a-map", []) == %{}
    end

    test "passes lists through unchanged for safety" do
      assert ActivityEditor.filter_objectives_to_existing([1, 2, 3], []) == [1, 2, 3]
    end
  end
end
