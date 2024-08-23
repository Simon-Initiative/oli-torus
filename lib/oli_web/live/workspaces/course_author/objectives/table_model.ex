defmodule OliWeb.Workspaces.CourseAuthor.Objectives.TableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  def new(objectives) do
    SortableTableModel.new(
      rows: objectives,
      column_specs: [
        %ColumnSpec{
          name: :title,
          label: "Title",
          sort_fn: &__MODULE__.sort_title_column/2
        },
        %ColumnSpec{
          name: :sub_objectives_count,
          label: "# of Sub-Objectives"
        },
        %ColumnSpec{
          name: :page_attachments_count,
          label: "# of Page Attachments"
        },
        %ColumnSpec{
          name: :activity_attachments_count,
          label: "# of Activity Attachments"
        }
      ],
      event_suffix: "",
      id_field: [:id]
    )
  end

  def sort_title_column(sort_order, _sort_spec),
    do: {fn r -> String.downcase(r.title) end, sort_order}
end
