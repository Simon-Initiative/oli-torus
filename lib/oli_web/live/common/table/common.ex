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
    Timex.format!(Map.get(item, name), "{relative}", :relative)
  end

  def render_short_date(_, item, %ColumnSpec{name: name}) do
    Map.get(item, name)
    |> Timex.format!("%Y-%m-%d", :strftime)
  end
end
