defmodule OliWeb.Grades.ObserveTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  use Surface.LiveComponent

  def new(updates) do
    SortableTableModel.new(
      rows: updates,
      column_specs: [
        %ColumnSpec{
          name: :user,
          label: "User"
        },
        %ColumnSpec{
          name: :status,
          label: "Status"
        },
        %ColumnSpec{
          name: :attempt,
          label: "Attempt"
        },
        %ColumnSpec{
          name: :details,
          label: "Details"
        },
        %ColumnSpec{
          name: :title,
          label: "Page Title"
        }
      ],
      event_suffix: "",
      id_field: [:index]
    )
  end

  def render(assigns) do
    ~F"""
    <div>nothing</div>
    """
  end
end
