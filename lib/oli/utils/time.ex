defmodule Oli.Utils.Time do
  def now() do
    {:ok, datetime} = DateTime.now("Etc/UTC")
    datetime
  end

  def one_minute, do: 60
  def one_hour, do: one_minute() * 60
  def one_day, do: one_hour() * 24
  def one_week, do: one_day() * 7
end
