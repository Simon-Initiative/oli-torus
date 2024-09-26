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

  describe "days_difference/3" do
    setup do
      stub_real_current_time()

      [
        context: %OliWeb.Common.SessionContext{
          browser_timezone: "America/Montevideo",
          local_tz: "America/Montevideo",
          author: nil,
          user: nil,
          is_liveview: false
        }
      ]
    end

    test "returns 'Due Today' when the resource end date is today", %{context: ctx} do
      today = Oli.DateTime.utc_now()
      assert Utils.days_difference(today, :due_by, ctx) == "Due Today"
    end

    test "returns '1 day left' when the resource end date is tomorrow", %{context: ctx} do
      tomorrow = Oli.DateTime.utc_now() |> Timex.shift(days: 1)
      assert Utils.days_difference(tomorrow, :due_by, ctx) == "1 day left"
    end

    test "returns 'Past Due by a day' when the resource end date was yesterday", %{context: ctx} do
      yesterday = Oli.DateTime.utc_now() |> Timex.shift(days: -1)
      assert Utils.days_difference(yesterday, :due_by, ctx) == "Past Due by a day"
    end

    test "returns 'Past Due by X days' when the resource end date was X days ago", %{context: ctx} do
      days_ago = 5
      past_date = Oli.DateTime.utc_now() |> Timex.shift(days: -days_ago)
      assert Utils.days_difference(past_date, :due_by, ctx) == "Past Due by #{days_ago} days"
    end

    test "returns 'X days left' when the resource end date is X days in the future", %{
      context: ctx
    } do
      days_ahead = 7
      future_date = Oli.DateTime.utc_now() |> Timex.shift(days: days_ahead)
      assert Utils.days_difference(future_date, :due_by, ctx) == "#{days_ahead} days left"
    end

    test "still returns 'Past Due by a day' when the resource end date was yesterday but less than 24 hours ago",
         %{
           context: ctx
         } do
      # Stub the current time to 3:00:00 AM in UTC, which is 12:00:00 AM the 24th in Montevideo
      stub_current_time(~U[2024-06-24 03:00:00Z])

      # The end date is 2:59:59 AM in UTC, which is 11:59:59 PM the 23th in Montevideo
      previous_day = ~U[2024-06-24 02:59:59Z]
      assert Utils.days_difference(previous_day, :due_by, ctx) == "Past Due by a day"
    end

    test "still returns 'X days left' when the resource end date cannot be localized" do
      ctx = nil
      days_ahead = 7
      future_date = Oli.DateTime.utc_now() |> Timex.shift(days: days_ahead)
      assert Utils.days_difference(future_date, :due_by, ctx) == "#{days_ahead} days left"
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

  describe "attempt_expires?/4" do
    test "returns false when an attempt does not expire" do
      refute Utils.attempt_expires?(:submitted, 0, :allow, ~U[2024-05-12 00:15:00Z])
      refute Utils.attempt_expires?(:submitted, 0, :allow, nil)
      refute Utils.attempt_expires?(:submitted, 10, :allow, ~U[2024-05-12 00:15:00Z])
      refute Utils.attempt_expires?(:submitted, 10, :disallow, ~U[2024-05-12 00:15:00Z])
      refute Utils.attempt_expires?(:active, 0, :allow, ~U[2024-05-12 00:15:00Z])
    end

    test "returns true when an attempt expires" do
      assert Utils.attempt_expires?(:active, 0, :disallow, ~U[2024-05-12 00:15:00Z])
      assert Utils.attempt_expires?(:active, 10, :disallow, ~U[2024-05-12 00:15:00Z])
      assert Utils.attempt_expires?(:active, 10, :allow, ~U[2024-05-12 00:15:00Z])
    end
  end

  describe "effective_attempt_expiration_date/4" do
    setup do
      stub_current_time(~U[2024-05-12 10:00:00Z])
      :ok
    end

    test "returns the end date when late submit is disallowed and there is no time limit" do
      assert Utils.effective_attempt_expiration_date(
               ~U[2024-05-12 09:30:00Z],
               0,
               :disallow,
               ~U[2024-05-20 09:30:00Z]
             ) == ~U[2024-05-20 09:30:00Z]
    end

    test "returns the calculated end date (inserted at + time limit) when late submit is allowed and there is a time limit" do
      assert Utils.effective_attempt_expiration_date(
               ~U[2024-05-12 09:30:00Z],
               15,
               :allow,
               ~U[2024-05-20 09:30:00Z]
             ) == ~U[2024-05-12 09:45:00.000000Z]
    end

    test "returns end date if the calculated end date (inserted at + time limit) is later than the end date" do
      assert Utils.effective_attempt_expiration_date(
               ~U[2024-05-12 09:30:00Z],
               15,
               :disallow,
               ~U[2024-05-12 09:40:00Z]
             ) == ~U[2024-05-12 09:40:00Z]
    end

    test "returns the calculated end date (inserted at + time limit) if the end date is later than the calculated one" do
      assert Utils.effective_attempt_expiration_date(
               ~U[2024-05-12 09:30:00Z],
               15,
               :disallow,
               ~U[2024-05-12 10:00:00Z]
             ) == ~U[2024-05-12 09:45:00.000000Z]
    end
  end

  describe "format_time_remaining/1" do
    setup do
      stub_current_time(~U[2024-05-12 10:00:00Z])
      :ok
    end

    test "returns an hour time remaining format if the remaining time is minor than a day" do
      assert Utils.format_time_remaining(~U[2024-05-12 11:30:03Z]) == "01:30:03"
    end

    test "returns an day time remaining format if the remaining time is bigger than a day" do
      assert Utils.format_time_remaining(~U[2024-05-14 11:30:20Z]) == "02:01:30:20"
    end

    test "returns zero time left in hour format if time remaining is negative" do
      assert Utils.format_time_remaining(~U[2024-05-10 11:30:20Z]) == "00:00:00"
    end
  end
end
