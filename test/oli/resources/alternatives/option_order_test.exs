defmodule Oli.Resources.Alternatives.OptionOrderTest do
  use ExUnit.Case, async: true

  alias Oli.Resources.Alternatives.OptionOrder

  test "moves an option to a drop target while preserving stable option maps" do
    first = %{"id" => "first", "name" => "First"}
    second = %{"id" => "second", "name" => "Second"}
    third = %{"id" => "third", "name" => "Third", "metadata" => %{"stable" => true}}

    assert {:ok, [^second, ^third, ^first]} =
             OptionOrder.move_to([first, second, third], "first", 3)

    assert {:ok, [^third, ^first, ^second]} =
             OptionOrder.move_to([first, second, third], "third", 0)
  end

  test "rejects invalid drop targets" do
    options = [%{"id" => "first"}, %{"id" => "second"}]

    assert {:error, :invalid_reorder} = OptionOrder.move_to(options, "missing", 1)
    assert {:error, :invalid_reorder} = OptionOrder.move_to(options, "first", -1)
    assert {:error, :invalid_reorder} = OptionOrder.move_to(options, "first", 3)
    assert {:error, :invalid_reorder} = OptionOrder.move_to(options, "first", "2")
  end

  test "identifies drops that do not change order" do
    options = [%{"id" => "first"}, %{"id" => "second"}]

    assert {:ok, :unchanged} = OptionOrder.move_to(options, "first", 0)
    assert {:ok, :unchanged} = OptionOrder.move_to(options, "first", 1)
    assert {:ok, :unchanged} = OptionOrder.move_to(options, "second", 1)
    assert {:ok, :unchanged} = OptionOrder.move_to(options, "second", 2)
  end
end
