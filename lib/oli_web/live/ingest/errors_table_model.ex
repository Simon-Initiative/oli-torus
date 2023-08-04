defmodule OliWeb.Admin.Ingest.ErrorsTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  use Phoenix.Component

  def new(errors) do
    SortableTableModel.new(
      rows: to_map(errors),
      column_specs: [
        %ColumnSpec{
          name: :error,
          label: "Error",
          render_fn: &__MODULE__.render_error/3
        }
      ],
      event_suffix: "",
      id_field: [:id]
    )
  end

  def update_rows(table_model, errors) do
    Map.put(table_model, :rows, to_map(errors))
  end

  defp to_map(errors) do
    Enum.with_index(errors)
    |> Enum.map(fn {e, i} -> %{error: e, id: i} end)
  end

  def render_error(_, row, _) do
    row.error
  end

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end
end
