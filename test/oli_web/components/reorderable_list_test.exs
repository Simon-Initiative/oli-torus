defmodule OliWeb.Components.ReorderableListTest do
  use ExUnit.Case, async: true

  alias OliWeb.Components.ReorderableList

  describe "keyboard_move/1" do
    test "uses the existing drop-target contract for Shift+Arrow movement" do
      assert {:move, 1, 0} =
               ReorderableList.keyboard_move(%{
                 "key" => "ArrowUp",
                 "shiftKey" => true,
                 "position" => "1",
                 "count" => "3"
               })

      assert {:move, 1, 3} =
               ReorderableList.keyboard_move(%{
                 "key" => "ArrowDown",
                 "shiftKey" => true,
                 "position" => "1",
                 "count" => "3"
               })
    end

    test "ignores boundaries, unmodified arrows, and malformed positions" do
      assert :noop =
               ReorderableList.keyboard_move(%{
                 "key" => "ArrowUp",
                 "shiftKey" => true,
                 "position" => "0",
                 "count" => "2"
               })

      assert :noop =
               ReorderableList.keyboard_move(%{
                 "key" => "ArrowDown",
                 "shiftKey" => true,
                 "position" => "1",
                 "count" => "2"
               })

      assert :noop =
               ReorderableList.keyboard_move(%{
                 "key" => "ArrowDown",
                 "shiftKey" => false,
                 "position" => "0",
                 "count" => "2"
               })

      assert :noop =
               ReorderableList.keyboard_move(%{
                 "key" => "ArrowDown",
                 "shiftKey" => true,
                 "position" => "invalid",
                 "count" => "2"
               })
    end
  end
end
