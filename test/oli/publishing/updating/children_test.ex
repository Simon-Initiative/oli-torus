defmodule Oli.Publishing.Updating.ChildrenTest do
  use ExUnit.Case, async: true

  alias Oli.Publishing.Updating.Children

  test "update works for all types of changes" do
    # no change between source versions
    assert Children.update([1], [1], [2]) == {:no_change}
    # no change between original source and destination
    assert Children.update([1], [2], [1]) == {:ok, [2]}

    # :other, :other
    assert Children.update([1], [2], [3, 4]) == {:ok, [3, 4, 2]}

    # source: other
    # dest: append
    assert Children.update([1], [2], [1, 3]) == {:ok, [2, 3]}

    # source: other
    # dest: append
    assert Children.update([1], [2], [1, 3]) == {:ok, [2, 3]}
  end
end
