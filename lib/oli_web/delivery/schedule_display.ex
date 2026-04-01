defmodule OliWeb.Delivery.ScheduleDisplay do
  @moduledoc """
  Shared schedule display helpers for availability and due dates.
  """

  alias OliWeb.Common.FormatDateTime

  @default_format "{WDshort} {Mshort} {D}, {YYYY}"

  def available_date(date, ctx, format \\ @default_format)

  def available_date(date, _ctx, _format) when date in [nil, "", "Not yet scheduled"],
    do: "Now"

  def available_date(date, ctx, format) do
    format_datetime(date, ctx, format)
  end

  def due_date(date, ctx, format \\ @default_format)

  def due_date(date, _ctx, _format) when date in [nil, "", "Not yet scheduled"],
    do: "None"

  def due_date(date, ctx, format) do
    format_datetime(date, ctx, format)
  end

  defp format_datetime(date, ctx, format) do
    FormatDateTime.to_formatted_datetime(date, ctx, format)
  end
end
