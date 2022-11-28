defmodule Oli.Publishing.Updating.AirroTest do
  use ExUnit.Case, async: true

  alias Oli.Publishing.Updating.Airro

  test "classify works for all types of changes" do
    # All cases when the lengths are the same:
    assert Airro.classify([], []) == {:equal}
    assert Airro.classify([1], [1]) == {:equal}

    assert Airro.classify([1, 2], [2, 1]) == {:reorder}

    assert Airro.classify([1, 2], [3, 1]) == {:other}
    assert Airro.classify([1], [2]) == {:other}

    # All cases when the length of a is less than length of b:
    assert Airro.classify([], [1]) == {:append, [1]}
    assert Airro.classify([1, 2, 3], [1, 2, 3, 4, 5]) == {:append, [4, 5]}

    assert Airro.classify([1], [2, 1]) == {:insert, [{2, 0}]}
    assert Airro.classify([1, 2, 3], [1, 2, 9, 3]) == {:insert, [{9, 2}]}
    assert Airro.classify([1, 2, 3], [1, 8, 2, 3, 9]) == {:insert, [{8, 1}, {9, 4}]}

    assert Airro.classify([1, 2, 3], [2, 1, 3, 4, 5]) == {:other}

    # The two cases when the length of a is greater than length of b:
    assert Airro.classify([1, 2, 3], [1]) == {:remove, [2, 3]}
    assert Airro.classify([1, 2, 3], [1, 4]) == {:other}
  end
end
