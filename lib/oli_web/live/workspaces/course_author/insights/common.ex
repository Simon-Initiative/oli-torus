defmodule OliWeb.Workspaces.CourseAuthor.Insights.Common do
  alias OliWeb.Common.Table.ColumnSpec

  def truncate(float_or_nil) when is_nil(float_or_nil), do: nil
  def truncate(float_or_nil) when is_float(float_or_nil), do: Float.round(float_or_nil, 2)

  def format_percent(float_or_nil) when is_nil(float_or_nil), do: nil

  def format_percent(float_or_nil) when is_float(float_or_nil),
    do: "#{round(100 * float_or_nil)}%"

  def render_percentage(_, row, %ColumnSpec{name: field}) do
    row[field] |> format_percent()
  end

  def render_float(_, row, %ColumnSpec{name: field}) do
    row[field] |> truncate()
  end
end
