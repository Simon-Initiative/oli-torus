defmodule OliWeb.Common.Table.Common do
  alias OliWeb.Common.Table.ColumnSpec
  alias OliWeb.Common.Utils

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

  def render_date(assigns, item, %ColumnSpec{name: name}) do
    Utils.render_date(item, name, Map.get(assigns, :context))
  end
end
