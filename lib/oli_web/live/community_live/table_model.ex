defmodule OliWeb.CommunityLive.TableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  def new(communities) do
    SortableTableModel.new(
      rows: communities,
      column_specs: [
        %ColumnSpec{
          name: :name,
          label: "Name"
        },
        %ColumnSpec{
          name: :description,
          label: "Description"
        },
        %ColumnSpec{
          name: :key_contact,
          label: "Key Contact"
        },
        %ColumnSpec{
          name: :inserted_at,
          label: "Created",
          render_fn: &SortableTableModel.render_date_column/3
        }
      ],
      event_suffix: "",
      id_field: [:id]
    )
  end
end
