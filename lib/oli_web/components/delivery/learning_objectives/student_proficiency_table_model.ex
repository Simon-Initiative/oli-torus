defmodule OliWeb.Delivery.LearningObjectives.StudentProficiencyTableModel do
  use Phoenix.Component

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  def new(student_data, opts \\ []) do
    sort_by_spec = Keyword.get(opts, :sort_by_spec)
    sort_order = Keyword.get(opts, :sort_order)

    column_specs = [
      %ColumnSpec{
        name: :student_name,
        label: "Student Name",
        render_fn: &custom_render/3,
        sortable: true,
        th_class: "w-1/2"
      },
      %ColumnSpec{
        name: :activities_attempted,
        label: "Activities Attempted",
        render_fn: &custom_render/3,
        sortable: false
      }
    ]

    if sort_by_spec && sort_order do
      SortableTableModel.new(
        rows: student_data,
        column_specs: column_specs,
        event_suffix: "",
        id_field: [:student_id],
        sort_by_spec: sort_by_spec,
        sort_order: sort_order,
        data: %{}
      )
    else
      SortableTableModel.new(
        rows: student_data,
        column_specs: column_specs,
        event_suffix: "",
        id_field: [:student_id],
        data: %{}
      )
    end
  end

  def custom_render(_assigns, student, %ColumnSpec{name: :student_name}) do
    student.student_name
  end

  def custom_render(_assigns, _student, %ColumnSpec{name: :activities_attempted}) do
    "3 out of 9"
  end
end