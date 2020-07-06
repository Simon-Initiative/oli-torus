defmodule OliWeb.Common.Table.SortableTableModel do

  alias OliWeb.Common.Table.ColumnSpec

  defstruct rows: [],
    column_specs: [],
    selected: nil,
    sort_by_spec: nil,
    sort_order: :asc,
    event_suffix: ""

  def new(rows: rows, column_specs: column_specs, event_suffix: event_suffix) do

    model = %__MODULE__{rows: rows, column_specs: column_specs, event_suffix: event_suffix, sort_by_spec: hd(column_specs)}
    |> sort

    {:ok, model}
  end

  def new(rows: rows, column_specs: column_specs, event_suffix: event_suffix, sort_by_spec: sort_by_spec) do

    model = %__MODULE__{rows: rows, column_specs: column_specs, event_suffix: event_suffix, sort_by_spec: sort_by_spec}
    |> sort

    {:ok, model}
  end

  def update_sort_params(%__MODULE__{sort_order: sort_order} = struct, column_name) do

    current_spec_name = struct.sort_by_spec.name

    case Enum.find(struct.column_specs, fn spec -> spec.name == column_name end) do
      %{name: ^current_spec_name} -> Map.put(struct, :sort_order, if sort_order == :asc do :desc else :asc end)
      spec -> Map.put(struct, :sort_by_spec, spec)
    end

  end

  def update_sort_params_and_sort(%__MODULE__{} = struct, column_name) do
    update_sort_params(struct, column_name)
    |> sort
  end

  def sort(%__MODULE__{rows: rows, sort_by_spec: sort_by_spec, sort_order: sort_order} = struct) do

    sort_fn = case sort_by_spec.sort_fn do
      nil -> ColumnSpec.default_sort_fn(sort_order, sort_by_spec)
      func -> func.(sort_order, sort_by_spec)
    end

    struct
    |> Map.put(:rows, Enum.sort(rows, sort_fn))
  end

end
