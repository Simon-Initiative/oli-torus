defmodule OliWeb.Delivery.Student.UtilsTest do
  use OliWeb.ConnCase

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

  describe "days_difference/1" do
    setup do
      stub_current_time(DateTime.utc_now())
      :ok
    end

    test "returns 'Due Today' when the resource end date is today" do
      today = Oli.DateTime.utc_now()
      assert Utils.days_difference(today) == "Due Today"
    end

    test "returns '1 day left' when the resource end date is tomorrow" do
      tomorrow = Oli.DateTime.utc_now() |> Timex.shift(days: 1)
      assert Utils.days_difference(tomorrow) == "1 day left"
    end

    test "returns 'Past Due' when the resource end date was yesterday" do
      yesterday = Oli.DateTime.utc_now() |> Timex.shift(days: -1)
      assert Utils.days_difference(yesterday) == "Past Due"
    end

    test "returns 'Past Due by X days' when the resource end date was X days ago" do
      days_ago = 5
      past_date = Oli.DateTime.utc_now() |> Timex.shift(days: -days_ago)
      assert Utils.days_difference(past_date) == "Past Due by #{days_ago} days"
    end

    test "returns 'X days left' when the resource end date is X days in the future" do
      days_ahead = 7
      future_date = Oli.DateTime.utc_now() |> Timex.shift(days: days_ahead)
      assert Utils.days_difference(future_date) == "#{days_ahead} days left"
    end
  end

  describe "parse_score/1" do
    test "rounds a score to two decimal places and returns a float if not a whole number" do
      assert Utils.parse_score(84.236) == 84.24
    end

    test "rounds a score to two decimal places and returns an integer if a whole number" do
      assert Utils.parse_score(85.00) == 85
    end

    test "returns an integer if the score is already a whole number" do
      assert Utils.parse_score(90.0) == 90
    end

    test "handles negative numbers correctly" do
      assert Utils.parse_score(-85.555) == -85.56
      assert Utils.parse_score(-42.0) == -42
    end

    test "handles zero correctly" do
      assert Utils.parse_score(0.0) == 0
    end

    test "handles small floating-point numbers correctly" do
      assert Utils.parse_score(0.004) == 0.00
      assert Utils.parse_score(0.005) == 0.01
    end
  end
end
