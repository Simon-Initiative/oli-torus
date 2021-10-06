defmodule OliWeb.Common.Table.Common do
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
end
