defmodule OliWeb.Grades.FailedGradeSyncTableModel do
  use Surface.LiveComponent

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  def new(failed_resource_accesses) do
    SortableTableModel.new(
      rows: failed_resource_accesses,
      column_specs: [
        %ColumnSpec{
          name: :user_name,
          label: "Student Name"
        },
        %ColumnSpec{
          name: :page_title,
          label: "Page title"
        },
        %ColumnSpec{
          name: :action,
          label: "Action",
          render_fn: &__MODULE__.render_retry_column/3
        }
      ],
      event_suffix: "",
      id_field: [:id]
    )
  end

  def render_retry_column(assigns, item, _) do
    ~F"""
    <button
      class="btn btn-primary"
      phx-click="retry"
      phx-value-resource-id={item.resource_id}
      phx-value-user-id={item.user_id}
    >Retry</button>
    """
  end

  def render(assigns) do
    ~F"""
    <div>nothing</div>
    """
  end
end
