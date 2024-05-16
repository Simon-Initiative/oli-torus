defmodule OliWeb.Delivery.Student.UtilsTest do
  use ExUnit.Case, async: true

  alias OliWeb.Delivery.Student.Utils

  describe "week_range/2" do
    test "calculates the correct week range based on week number and start date" do
      section_start_date = ~U[2024-01-01 00:00:00Z]
      {start_date, end_date} = Utils.week_range(5, section_start_date)

      assert start_date == ~D[2024-01-28]
      assert end_date == ~D[2024-02-03]
    end

    test "returns the first week when week number is 1" do
      section_start_date = ~U[2024-01-01 00:00:00Z]
      {start_date, end_date} = Utils.week_range(1, section_start_date)

      assert start_date == ~D[2023-12-31]
      assert end_date == ~D[2024-01-06]
    end

    test "adjusts for weeks later in the year" do
      section_start_date = ~U[2024-01-01 00:00:00Z]
      {start_date, end_date} = Utils.week_range(10, section_start_date)

      assert start_date == ~D[2024-03-03]
      assert end_date == ~D[2024-03-09]
    end

    test "handles leap year adjustments" do
      section_start_date = ~U[2020-01-01 00:00:00Z]
      {start_date, end_date} = Utils.week_range(10, section_start_date)

      assert start_date == ~D[2020-03-01]
      assert end_date == ~D[2020-03-07]
    end
  end
end
