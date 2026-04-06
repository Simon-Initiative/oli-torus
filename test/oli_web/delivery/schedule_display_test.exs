defmodule OliWeb.Delivery.ScheduleDisplayTest do
  use ExUnit.Case, async: true

  alias OliWeb.Common.SessionContext
  alias OliWeb.Delivery.ScheduleDisplay

  describe "available_date/3" do
    test "returns Now when there is no available date" do
      assert ScheduleDisplay.available_date(nil, ctx()) == "Now"
    end

    test "formats dates with the default format" do
      assert ScheduleDisplay.available_date(datetime(), ctx()) == "Mon Mar 30, 2026"
    end

    test "supports a custom format" do
      assert ScheduleDisplay.available_date(
               datetime(),
               ctx(),
               "{WDshort}, {Mshort} {D}, {YYYY} ({h12}:{m}{am})"
             ) == "Mon, Mar 30, 2026 (2:45pm)"
    end
  end

  describe "due_date/3" do
    test "returns None when there is no due date" do
      assert ScheduleDisplay.due_date(nil, ctx()) == "None"
    end

    test "formats dates with the default format" do
      assert ScheduleDisplay.due_date(datetime(), ctx()) == "Mon Mar 30, 2026"
    end
  end

  defp ctx do
    %SessionContext{
      browser_timezone: "Etc/UTC",
      local_tz: "Etc/UTC",
      is_liveview: true,
      author: nil,
      user: nil
    }
  end

  defp datetime, do: ~U[2026-03-30 14:45:00Z]
end
