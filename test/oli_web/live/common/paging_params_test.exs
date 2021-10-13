defmodule OliWeb.Common.PagingParamsTest do
  use ExUnit.Case, async: true

  alias OliWeb.Common.PagingParams

  test "calculating params" do
    check = fn p, rpc, sp, cp, lp ->
      assert %{
               rendered_pages_count: ^rpc,
               start_page_index: ^sp,
               current_page_index: ^cp,
               last_page_index: ^lp
             } = p
    end

    # Test last page index calculation
    check.(PagingParams.calculate(100, 0, 10, 9), 9, 0, 0, 9)
    check.(PagingParams.calculate(101, 0, 10, 9), 9, 0, 0, 10)
    check.(PagingParams.calculate(1001, 0, 10, 9), 9, 0, 0, 100)
    check.(PagingParams.calculate(999, 0, 10, 9), 9, 0, 0, 99)

    # Test cases when there are less than nine pages of results
    check.(PagingParams.calculate(1, 0, 10, 9), 1, 0, 0, 0)
    check.(PagingParams.calculate(18, 0, 10, 9), 2, 0, 0, 1)
    check.(PagingParams.calculate(18, 10, 10, 9), 2, 0, 1, 1)

    # Test cases when we can center the current
    check.(PagingParams.calculate(1000, 500, 10, 9), 9, 46, 50, 99)

    # And a case when there aren't enough to the right of current to center
    check.(PagingParams.calculate(1000, 970, 10, 9), 9, 91, 97, 99)
    check.(PagingParams.calculate(1000, 980, 10, 9), 9, 91, 98, 99)
    check.(PagingParams.calculate(1000, 990, 10, 9), 9, 91, 99, 99)

    # Simulate paging ahead, and watch the start remain at 0 until there
    # are enough pages to the left of center to slide the start
    check.(PagingParams.calculate(1000, 10, 10, 9), 9, 0, 1, 99)
    check.(PagingParams.calculate(1000, 20, 10, 9), 9, 0, 2, 99)
    check.(PagingParams.calculate(1000, 30, 10, 9), 9, 0, 3, 99)
    check.(PagingParams.calculate(1000, 40, 10, 9), 9, 0, 4, 99)
    check.(PagingParams.calculate(1000, 50, 10, 9), 9, 1, 5, 99)
    check.(PagingParams.calculate(1000, 60, 10, 9), 9, 2, 6, 99)

    # Check with 5 max rendered pages
    check.(PagingParams.calculate(1000, 60, 10, 5), 5, 4, 6, 99)
  end
end
