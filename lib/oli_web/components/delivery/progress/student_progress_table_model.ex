defmodule OliWeb.Components.Delivery.StudentProgressTabelModel do
  use Surface.LiveComponent
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Progress.ResourceTitle

  def new(rows, section_slug, student_id, ctx) do
    SortableTableModel.new(
      rows: rows,
      column_specs: [
        %ColumnSpec{
          name: :index,
          label: "Order",
          td_class: "text-center pl-0",
          th_class: "!text-center"
        },
        %ColumnSpec{
          name: :title,
          label: "Resource Title",
          render_fn: &__MODULE__.custom_render/3
        },
        %ColumnSpec{
          name: :type,
          label: "Type"
        },
        %ColumnSpec{
          name: :score,
          label: "Score",
          render_fn: &__MODULE__.custom_render/3,
          sortable: false,
          td_class: "text-center",
          th_class: "!text-center"
        },
        %ColumnSpec{
          name: :number_attempts,
          label: "# Attempts",
          render_fn: &__MODULE__.custom_render/3,
          sortable: false,
          td_class: "text-center",
          th_class: "!text-center"
        },
        %ColumnSpec{
          name: :number_accesses,
          label: "# Accesses",
          render_fn: &__MODULE__.custom_render/3,
          sortable: false,
          td_class: "text-center",
          th_class: "!text-center"
        },
        %ColumnSpec{
          name: :inserted_at,
          label: "First Visited",
          render_fn: &OliWeb.Common.Table.Common.render_date/3,
          sortable: false
        },
        %ColumnSpec{
          name: :updated_at,
          label: "Last Visited",
          render_fn: &OliWeb.Common.Table.Common.render_date/3,
          sortable: false
        }
      ],
      event_suffix: "",
      id_field: [:index],
      data: %{
        section_slug: section_slug,
        user_id: student_id,
        ctx: ctx
      }
    )
  end

  def custom_render(assigns, row, %ColumnSpec{name: :title}) do
    ~F"""
      <ResourceTitle
        node={row.node}
        url={Routes.live_path(OliWeb.Endpoint, OliWeb.Progress.StudentResourceView, assigns.section_slug, assigns.user_id, row.resource_id)}
      />
    """
  end

  def custom_render(_assigns, row, %ColumnSpec{name: :score}) do
    if row.type == "Graded" and !is_nil(row.score), do: "#{row.score} / #{row.out_of}", else: ""
  end

  def custom_render(_assigns, row, %ColumnSpec{name: :number_accesses}) do
    if row.number_accesses == 0, do: "", else: row.number_accesses
  end

  def custom_render(_assigns, row, %ColumnSpec{name: :number_attempts}) do
    if row.number_attempts == 0, do: "", else: row.number_attempts
  end

  def render(assigns) do
    ~F"""
      <div>nothing</div>
    """
  end
end
