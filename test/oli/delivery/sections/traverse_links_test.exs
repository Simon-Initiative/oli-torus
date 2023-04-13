defmodule Oli.Delivery.Sections.TraverseLinksTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Sections

  test "traverse_links/4 indentifies unlinked pages" do

    # 1 -> 2 -> 3, leaving 4 unreachable
    {unreachable, _} = Sections.traverse_links(%{
      1 => [2],
      2 => [3]
    }, [1, 10, 11, 12], MapSet.new([2, 3, 4]), MapSet.new())

    assert MapSet.new([4]) == unreachable

  end

  test "traverse_links/4 avoids circular reference" do

    # 1 -> 2 -> 3 -> 1, leaving 4 unreachable
    {unreachable, _} = Sections.traverse_links(%{
      1 => [2],
      2 => [3],
      3 => [1]
    }, [1, 10, 11, 12], MapSet.new([2, 3, 4]), MapSet.new())

    assert MapSet.new([4]) == unreachable

  end

  test "traverse_links/4 properly handles mutiple links from one page" do

    # 1 -> 2 -> 3 and 2 -> 4, leaving none unreachable
    {unreachable, _} = Sections.traverse_links(%{
      1 => [2],
      2 => [3, 4]
    }, [1, 10, 11, 12], MapSet.new([2, 3, 4]), MapSet.new())

    assert MapSet.new([]) == unreachable

  end

end
