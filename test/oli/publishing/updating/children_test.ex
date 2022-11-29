defmodule Oli.Publishing.Updating.ChildrenTest do
  use ExUnit.Case, async: true

  alias Oli.Publishing.Updating.Children

  test "update works for all types of changes" do
    # no change between source versions
    assert Children.update([1], [1], [2]) == {:no_change}

    # no change between original source and destination
    assert Children.update([1], [2], [1]) == {:ok, [2]}

    # dest: append
    assert Children.update([1], [2], [1, 3]) == {:ok, [2, 3]}

    # dest: insert
    assert Children.update([1, 2, 3], [1, 3, 2], [0, 1, 2, 3]) == {:ok, [0, 1, 3, 2]}

    # dest: remove
    assert Children.update([1, 2, 3], [1, 3, 2], [2, 3]) == {:ok, [3, 2]}

    # source: append
    assert Children.update([1, 2], [1, 2, 3], [2, 1]) == {:ok, [2, 1, 3]}

    # source: insert
    assert Children.update([1, 2], [0, 1, 2], [2, 1]) == {:ok, [0, 2, 1]}

    # source: remove
    assert Children.update([1, 2, 3], [1, 3], [3, 2, 1]) == {:ok, [3, 1]}

    # :other, :other
    assert Children.update([1], [2], [3, 4]) == {:ok, [3, 4, 2]}
  end
end
