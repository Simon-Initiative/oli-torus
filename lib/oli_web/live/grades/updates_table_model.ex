defmodule OliWeb.Grades.UpdatesTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  use Phoenix.Component

  def new(updates, ctx) do
    inserted_at_spec = %ColumnSpec{
      name: :inserted_at,
      label: "Date/Time",
      render_fn: &OliWeb.Common.Table.Common.render_date/3,
      sort_fn: &OliWeb.Common.Table.Common.sort_date/2
    }

    SortableTableModel.new(
      rows: updates,
      column_specs: [
        %ColumnSpec{
          name: :user_email,
          label: "User"
        },
        %ColumnSpec{
          name: :result,
          label: "Result"
        },
        %ColumnSpec{
          name: :type,
          label: "Type"
        },
        %ColumnSpec{
          name: :attempt_number,
          label: "Update Attempt #"
        },
        %ColumnSpec{
          name: :score,
          label: "Score",
          render_fn: &__MODULE__.custom_render/3,
          sort_fn: &__MODULE__.custom_sort/2
        },
        %ColumnSpec{
          name: :details,
          label: "Details"
        },
        inserted_at_spec
      ],
      event_suffix: "",
      id_field: [:id],
      sort_by_spec: inserted_at_spec,
      sort_order: :desc,
      data: %{
        ctx: ctx
      }
    )
  end

  def custom_sort(direction, %ColumnSpec{name: name}) do
    {fn r ->
       case name do
         :score ->
           if !is_nil(r.score) and r.out_of != 0 do
             r.score / r.out_of
           else
             0.0
           end
       end
     end, direction}
  end

  def custom_render(_, row, %ColumnSpec{name: name}) do
    case name do
      :score ->
        if !is_nil(row.score) do
          "#{row.score} / #{row.out_of}"
        else
          ""
        end
    end
  end

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end
end
