defmodule OliWeb.Common.Table.ColumnSpec do

  @moduledoc """
  A column specification for sortable tables.

  A column specification instructs the sortable table as to how to display a header,
  render row values, and sort columns.

  The `:name` attribute must be the property of a row item, where `Map.put(row, name)` allows access
  to the value of the item for that column.

  The `:label` attribute is a user friendly name that the table will display in the table header

  The `:sort_fn` is a function that takes two arguments, the current sort direction (:asc or :desc) and
  the column spec - and returns a comparator function that will be used to sort the table.  Leaving this
  set to `nil` instructs the sorted table to fall back to a default sort comparator that simply
  accesses the column values and compares using the less than and greater than operators. The fall back
  sort function is implemented to be a stable sort.

  The `:render_fn` is a function that takes three arguments, the current `assigns` for the parent LiveView,
  the current row to be rendered, and the column spec to render.  Leaving this attribute set to nil
  instructs the sortable table to fall back to a default implementation that renders the result of
  `Map.get(row, column_spec.name)`

  """

  defstruct name: nil,   # field name of the column, must be able to use this to do `Map.get(row, :name)`
    label: nil,          # friendly label to display for this column
    sort_fn: nil,        # a function that takes two arguments, a sort direction and column spec and returns
                         # a function that can then be used as a sort comparator
    render_fn: nil

  def default_sort_fn(:asc, %{name: name}), do: fn row1, row2 -> Map.get(row1, name) <= Map.get(row2, name) end
  def default_sort_fn(:desc, %{name: name}), do: fn row1, row2 -> Map.get(row2, name) <= Map.get(row1, name) end

  def default_render_fn(spec, row), do: Map.get(row, spec.name)

end
