defmodule Oli.Activities.ParseUtilsTest do

  use ExUnit.Case, async: true

  alias Oli.Activities.ParseUtils

  test "items_or_errors/1 handles empty list" do
    assert {:ok, []} == ParseUtils.items_or_errors([])
  end

  test "items_or_errors/1 handles all oks" do
    assert {:ok, [1, 2, 3]} = ParseUtils.items_or_errors([
      {:ok, 1},
      {:ok, 2},
      {:ok, 3},
    ])
  end

  test "items_or_errors/1 handles all errors" do
    assert {:error, [1, 2, 3]} = ParseUtils.items_or_errors([
      {:error, 1},
      {:error, 2},
      {:error, 3},
    ])
  end

  test "items_or_errors/1 handles a mixture" do
    assert {:error, [2]} = ParseUtils.items_or_errors([
      {:ok, 1},
      {:error, 2},
      {:ok, 3},
    ])
  end

end
