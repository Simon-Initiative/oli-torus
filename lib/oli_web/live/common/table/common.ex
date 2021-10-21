defmodule OliWeb.Common.Table.Common do
  alias OliWeb.Common.Table.ColumnSpec

  def sort_date(direction, spec) do
    {fn r ->
       case Map.get(r, spec.name) do
         nil ->
           0

         d ->
           DateTime.to_unix(d)
       end
     end, direction}
  end

  def render_relative_date(_, item, %ColumnSpec{name: name}) do
    case Map.get(item, name) do
      nil -> ""
      d -> Timex.format!(d, "{relative}", :relative)
    end
  end

  def render_short_date(_, item, %ColumnSpec{name: name}) do
    case Map.get(item, name) do
      nil -> ""
      d -> Timex.format!(d, "%Y-%m-%d", :strftime)
    end
  end
end
