defmodule Oli.Publishing.Updating.MergeTest do
  use ExUnit.Case, async: true

  alias Oli.Publishing.Updating.Merge

  test "update works for all types of changes" do
    # no change between source versions
    assert Merge.merge([1], [1], [2]) == {:no_change}

    # no change between original source and destination
    assert Merge.merge([1], [2], [1]) == {:ok, [2]}

    # dest: append
    assert Merge.merge([1], [2], [1, 3]) == {:ok, [2, 3]}

    # dest: insert
    assert Merge.merge([1, 2, 3], [1, 3, 2], [0, 1, 2, 3]) == {:ok, [0, 1, 3, 2]}

    # dest: remove
    assert Merge.merge([1, 2, 3], [1, 3, 2], [2, 3]) == {:ok, [3, 2]}

    # source: append
    assert Merge.merge([1, 2], [1, 2, 3], [2, 1]) == {:ok, [2, 1, 3]}

    # source: insert
    assert Merge.merge([1, 2], [0, 1, 2], [2, 1]) == {:ok, [0, 2, 1]}

    # source: remove
    assert Merge.merge([1, 2, 3], [1, 3], [3, 2, 1]) == {:ok, [3, 1]}

    # :other, :other
    assert Merge.merge([1], [2], [3, 4]) == {:ok, [3, 4, 2]}
  end
end
