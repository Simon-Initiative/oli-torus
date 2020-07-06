defmodule OliWeb.Common.Table.ColumnSpec do

  defstruct name: nil,
    label: nil,
    sort_fn: nil,
    render_fn: nil

  def default_sort_fn(:asc, %{name: name}), do: fn row1, row2 -> Map.get(row1, name) < Map.get(row2, name) end
  def default_sort_fn(:desc, %{name: name}), do: fn row1, row2 -> Map.get(row2, name) < Map.get(row1, name) end

  def default_render_fn(name, row), do: Map.get(row, name)

end
